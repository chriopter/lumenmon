/**
 * Lumenmon Widget System
 * Modular widgets that mirror agent collector structure.
 * Each widget declares its metrics, type, and render function.
 */

window.LumenmonWidgets = {
    registered: {},
    instances: {},

    /**
     * Register a widget
     * @param {Object} config - Widget configuration
     * @param {string} config.name - Unique widget name (e.g., 'cpu', 'proxmox_zfs')
     * @param {string} config.title - Display title
     * @param {string} config.category - Category for grouping ('generic', 'proxmox')
     * @param {string[]} config.metrics - Metric patterns this widget handles (supports * wildcard)
     * @param {string} config.size - Widget size: 'sparkline' | 'stat' | 'chart' | 'table'
     * @param {number} config.interval - Refresh interval in ms (default: 1000)
     * @param {Function} config.render - Render function(container, data, agent)
     */
    register: function(config) {
        if (!config.name) {
            console.error('Widget missing name:', config);
            return;
        }
        this.registered[config.name] = {
            name: config.name,
            title: config.title || config.name,
            category: config.category || 'generic',
            metrics: config.metrics || [config.name],
            size: config.size || 'stat',
            interval: config.interval || 1000,
            render: config.render || function() {},
            init: config.init || null,  // Init function for charts
            update: config.update || null  // Optional update function for live refresh
        };
    },

    /**
     * Match metric name against widget patterns
     * @param {string} metricName - Metric name to match
     * @param {string[]} patterns - Patterns to match against (supports * wildcard)
     */
    matchesPattern: function(metricName, patterns) {
        return patterns.some(pattern => {
            if (pattern.includes('*')) {
                const regex = new RegExp('^' + pattern.replace(/\*/g, '.*') + '$');
                return regex.test(metricName);
            }
            return metricName === pattern;
        });
    },

    /**
     * Find widgets that match available metrics
     * @param {string[]} metricNames - Available metric names for this agent
     * @returns {Object[]} Matching widgets with their data
     */
    findMatching: function(metricNames) {
        const matched = [];

        for (const [name, widget] of Object.entries(this.registered)) {
            const matchingMetrics = metricNames.filter(m =>
                this.matchesPattern(m, widget.metrics)
            );

            if (matchingMetrics.length > 0) {
                matched.push({
                    widget: widget,
                    metrics: matchingMetrics
                });
            }
        }

        return matched;
    },

    /**
     * Render all matching widgets for an agent
     * @param {HTMLElement} container - Container element
     * @param {Object} agent - Agent data with metrics
     * @param {Object[]} tables - Metric tables from API
     */
    renderAll: function(container, agent, tables) {
        const metricNames = tables.map(t => t.metric_name);
        const matched = this.findMatching(metricNames);

        // Group by category
        const byCategory = {};
        matched.forEach(m => {
            const cat = m.widget.category;
            if (!byCategory[cat]) byCategory[cat] = [];
            byCategory[cat].push(m);
        });

        // Group by size within category
        const categoryOrder = ['generic', 'proxmox'];
        const sizeOrder = ['sparkline', 'stat', 'chart', 'table'];

        // Clear existing instances
        this.instances = {};

        // Build HTML structure
        let html = '';

        // Sparklines section (top overview)
        const sparklineWidgets = matched.filter(m => m.widget.size === 'sparkline');
        if (sparklineWidgets.length > 0) {
            html += '<div class="widget-sparklines">';
            sparklineWidgets.forEach(m => {
                const widgetData = this.getWidgetData(m.metrics, tables);
                html += `<div class="widget widget-sparkline" data-widget="${m.widget.name}">`;
                html += m.widget.render(widgetData, agent);
                html += '</div>';
                this.instances[m.widget.name] = { widget: m.widget, metrics: m.metrics };
            });
            html += '</div>';
        }

        // Stats row
        const statWidgets = matched.filter(m => m.widget.size === 'stat');
        if (statWidgets.length > 0) {
            html += '<div class="widget-stats">';
            statWidgets.forEach(m => {
                const widgetData = this.getWidgetData(m.metrics, tables);
                html += `<div class="widget widget-stat" data-widget="${m.widget.name}">`;
                html += m.widget.render(widgetData, agent);
                html += '</div>';
                this.instances[m.widget.name] = { widget: m.widget, metrics: m.metrics };
            });
            html += '</div>';
        }

        // Charts grid
        const chartWidgets = matched.filter(m => m.widget.size === 'chart');
        if (chartWidgets.length > 0) {
            html += '<div class="widget-charts">';
            chartWidgets.forEach(m => {
                const widgetData = this.getWidgetData(m.metrics, tables);
                html += `<div class="widget widget-chart" data-widget="${m.widget.name}">`;
                html += m.widget.render(widgetData, agent);
                html += '</div>';
                this.instances[m.widget.name] = { widget: m.widget, metrics: m.metrics };
            });
            html += '</div>';
        }

        // Tables section
        const tableWidgets = matched.filter(m => m.widget.size === 'table');
        if (tableWidgets.length > 0) {
            html += '<div class="widget-tables">';
            tableWidgets.forEach(m => {
                const widgetData = this.getWidgetData(m.metrics, tables);
                html += `<div class="widget widget-table" data-widget="${m.widget.name}">`;
                html += m.widget.render(widgetData, agent);
                html += '</div>';
                this.instances[m.widget.name] = { widget: m.widget, metrics: m.metrics };
            });
            html += '</div>';
        }

        container.innerHTML = html;

        // Initialize charts after DOM is ready
        chartWidgets.forEach(m => {
            if (m.widget.init) {
                const widgetData = this.getWidgetData(m.metrics, tables);
                const el = container.querySelector(`[data-widget="${m.widget.name}"]`);
                if (el) m.widget.init(el, widgetData, agent);
            }
        });
    },

    /**
     * Update all widgets with new data (for live refresh)
     * @param {HTMLElement} container - Container element
     * @param {Object} agent - Agent data
     * @param {Object[]} tables - Fresh metric tables
     */
    updateAll: function(container, agent, tables) {
        for (const [name, instance] of Object.entries(this.instances)) {
            const el = container.querySelector(`[data-widget="${name}"]`);
            if (!el) continue;

            const widgetData = this.getWidgetData(instance.metrics, tables);

            if (instance.widget.update) {
                // Use custom update function if available
                instance.widget.update(el, widgetData, agent);
            } else if (instance.widget.init) {
                // Chart widgets: re-render and re-init
                el.innerHTML = instance.widget.render(widgetData, agent);
                instance.widget.init(el, widgetData, agent);
            } else {
                // Default: re-render entire widget
                el.innerHTML = instance.widget.render(widgetData, agent);
            }
        }
    },

    /**
     * Get data for widget from tables
     * @param {string[]} metricNames - Metrics this widget needs
     * @param {Object[]} tables - All tables from API
     * @returns {Object} Data keyed by metric name
     */
    getWidgetData: function(metricNames, tables) {
        const data = {};
        metricNames.forEach(name => {
            const table = tables.find(t => t.metric_name === name);
            if (table) {
                data[name] = table;
            }
        });
        return data;
    },

    /**
     * Helper: Generate sparkline from values
     * @param {number[]} values - Array of values
     * @returns {string} Unicode sparkline
     */
    sparkline: function(values) {
        if (!values || values.length === 0) return '';
        const blocks = ['▁', '▂', '▃', '▄', '▅', '▆', '▇', '█'];
        const minVal = Math.min(...values);
        const maxVal = Math.max(...values);
        const range = maxVal - minVal || 1;
        return values.map(val => {
            const normalized = (val - minVal) / range;
            const index = Math.floor(normalized * (blocks.length - 1));
            return blocks[index];
        }).join('');
    }
};

// Shorthand for registering widgets
function LumenmonWidget(config) {
    window.LumenmonWidgets.register(config);
}
