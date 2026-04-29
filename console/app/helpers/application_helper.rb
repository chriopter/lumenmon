module ApplicationHelper
  def metric_time(time)
    time ? "#{time_ago_in_words(time)} ago" : "never"
  end

  def metric_next_update(sample)
    return "-" unless sample
    return "once" unless sample.interval.to_i.positive?

    next_at = sample.observed_at + sample.interval.seconds
    if next_at.future?
      "in #{compact_duration(next_at - Time.current)}"
    else
      "#{compact_duration(Time.current - next_at)} ago"
    end
  end

  def compact_duration(seconds)
    seconds = seconds.to_i.abs
    return "#{seconds}s" if seconds < 60
    return "#{seconds / 60}m" if seconds < 1.hour

    "#{seconds / 1.hour}h"
  end

  def updates_compact(agent)
    upd = update_widget(agent)
    return nil unless upd
    "#{upd[:total]}/#{upd[:security]}s"
  end

  def metric_sample(agent, name)
    agent&.dig(:metrics, name)
  end

  def metric_value(agent, name, fallback = "-")
    metric_sample(agent, name)&.typed_value || fallback
  end

  def metric_number(agent, name)
    Float(metric_sample(agent, name)&.typed_value)
  rescue ArgumentError, TypeError
    nil
  end

  def metric_percent(agent, name)
    value = metric_number(agent, name)
    value.nil? ? "-" : format("%.1f%%", value)
  end

  def metric_health_class(agent, name)
    sample = metric_sample(agent, name)
    return "unknown" unless sample

    value = metric_number(agent, name)
    return "unknown" unless value

    return "critical" if (!sample.min.nil? && value < sample.min) || (!sample.max.nil? && value > sample.max)
    return "warning" if (!sample.warn_min.nil? && value < sample.warn_min) || (!sample.warn_max.nil? && value > sample.warn_max)

    "online"
  end

  def metric_tone(agent, name)
    case metric_health_class(agent, name)
    when "critical" then "crit-text"
    when "warning"  then "warn-text"
    when "online"   then "ok-text"
    else nil
    end
  end

  def update_widget(agent)
    total = metric_number(agent, "debian_updates_total")&.to_i
    security = metric_number(agent, "debian_updates_security")&.to_i
    release = metric_number(agent, "debian_updates_release")&.to_i
    age = metric_number(agent, "debian_updates_age")&.to_i
    return nil if [total, security, release, age].all?(&:nil?)

    status = if release.to_i.positive? || security.to_i.positive? || age.to_i > 72
      "critical"
    elsif total.to_i.positive? || age.to_i > 24
      "warning"
    else
      "online"
    end

    { total: total || 0, security: security || 0, release: release || 0, age: age, status: status }
  end

  def proxmox_runtime(agent)
    vms_running = metric_number(agent, "proxmox_vms_running")
    vms_total = metric_number(agent, "proxmox_vms_total")
    containers_running = metric_number(agent, "proxmox_containers_running") || metric_number(agent, "proxmox_cts_running")
    containers_total = metric_number(agent, "proxmox_containers_total") || metric_number(agent, "proxmox_cts_total")
    return nil if [vms_running, vms_total, containers_running, containers_total].all?(&:nil?)

    {
      vms_running: vms_running&.to_i,
      vms_total: vms_total&.to_i,
      containers_running: containers_running&.to_i,
      containers_total: containers_total&.to_i
    }
  end

  def storage_pools(agent)
    pools = {}
    agent[:samples].each do |sample|
      match = sample.metric_name.match(/\Aproxmox_storage_(.+)_(used|total)\z/)
      next unless match

      pools[match[1]] ||= {}
      pools[match[1]][match[2].to_sym] = sample.typed_value.to_f
    end
    pools.map do |name, values|
      total = values[:total].to_f
      used = values[:used].to_f
      percent = total.positive? ? (used / total * 100).round : 0
      tone = if percent >= 90 then "crit"
      elsif percent >= 75 then "warn"
      else "ok"
      end
      { name: name.tr("_", "-"), used: used, total: total, percent: percent, tone: tone }
    end
  end

  def zfs_pools(agent)
    pools = {}
    agent[:samples].each do |sample|
      match = sample.metric_name.match(/\Aproxmox_zfs_(.+)_(drives|online|capacity)\z/)
      next unless match

      pools[match[1]] ||= {}
      pools[match[1]][match[2].to_sym] = sample.typed_value.to_f
    end
    pools.map do |name, values|
      {
        name: name.tr("_", "-"),
        drives: values[:drives]&.to_i,
        online: values[:online]&.to_i,
        capacity: values[:capacity]&.round
      }
    end
  end

  def zpool_health(agent)
    pools = {}
    agent[:samples].each do |sample|
      degraded = sample.metric_name.match(/\Aproxmox_zpool_(.+)_degraded\z/)
      if degraded
        pools[degraded[1]] ||= {}
        pools[degraded[1]][:degraded] = sample.typed_value.to_i
        next
      end
      upgrade = sample.metric_name.match(/\Aproxmox_zpool_(.+)_upgrade_needed\z/)
      if upgrade
        pools[upgrade[1]] ||= {}
        pools[upgrade[1]][:upgrade_needed] = sample.typed_value.to_i
      end
    end
    pools.map do |name, attrs|
      {
        name: name == "any" ? "any pool" : name.tr("_", "-"),
        degraded: attrs[:degraded].to_i.positive?,
        upgrade_needed: attrs[:upgrade_needed].to_i.positive?
      }
    end
  end

  def hardware_temps(agent)
    rows = agent[:samples].filter_map do |sample|
      match = sample.metric_name.match(/\Ahardware_temp_(.+?)(?:_c)?\z/)
      next unless match

      value = Float(sample.typed_value) rescue nil
      next unless value && value >= -10 && value <= 120

      { name: match[1].tr("_", " "), value: value }
    end
    rows.sort_by { |row| -row[:value] }.first(4)
  end

  def smart_disks(agent)
    grouped = {}
    agent[:samples].each do |sample|
      match = sample.metric_name.match(/\Ahardware_smart_(.+)_(health|temp_c|wear_pct|power_cycles)\z/)
      next unless match

      grouped[match[1]] ||= {}
      grouped[match[1]][match[2].to_sym] = sample.typed_value
    end
    grouped.map do |disk, attrs|
      health = attrs[:health].to_i
      {
        name: disk,
        healthy: health == 1,
        temp: attrs[:temp_c],
        wear: attrs[:wear_pct],
        cycles: attrs[:power_cycles]
      }
    end
  end

  def temp_tone(value)
    return "ok-text" unless value
    return "crit-text" if value > 85
    return "warn-text" if value > 80
    "ok-text"
  end

  def agent_mail_address(agent)
    "#{agent[:id]}@#{ENV.fetch("CONSOLE_HOST", "localhost")}"
  end

  def status_warnings(agent)
    warnings = []
    warnings << "MQTT USER MISSING" if agent[:has_mqtt_user] == false
    warnings << "SQL TABLES MISSING" if agent[:has_table] == false
    warnings.join(" · ")
  end
end
