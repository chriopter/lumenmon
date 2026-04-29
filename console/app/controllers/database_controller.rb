class DatabaseController < ApplicationController
  ROW_LIMIT = 1_000

  helper_method :database_cell_value

  def index
    @tables = table_names.map { |name| table_summary(name) }
    @selected_table = selected_table
    @columns = @selected_table ? column_names(@selected_table) : []
    @rows = @selected_table ? last_rows(@selected_table, @columns) : []
  end

  private

  def connection
    ActiveRecord::Base.connection
  end

  def table_names
    @table_names ||= connection.tables.sort
  end

  def selected_table
    requested = params[:table].to_s
    return requested if table_names.include?(requested)

    table_names.include?("metric_samples") ? "metric_samples" : table_names.first
  end

  def table_summary(table_name)
    { name: table_name, rows: count_rows(table_name), columns: column_names(table_name).count }
  end

  def count_rows(table_name)
    quoted_table = connection.quote_table_name(table_name)
    connection.select_value("SELECT COUNT(*) FROM #{quoted_table}").to_i
  rescue ActiveRecord::StatementInvalid
    0
  end

  def column_names(table_name)
    connection.columns(table_name).map(&:name)
  end

  def last_rows(table_name, columns)
    quoted_table = connection.quote_table_name(table_name)
    order_clause = order_clause_for(columns)
    connection.select_all("SELECT * FROM #{quoted_table} #{order_clause} LIMIT #{ROW_LIMIT}").to_a
  rescue ActiveRecord::StatementInvalid
    []
  end

  def order_clause_for(columns)
    order_column = %w[id updated_at created_at observed_at].find { |name| columns.include?(name) }
    return "" unless order_column

    "ORDER BY #{connection.quote_column_name(order_column)} DESC"
  end

  def database_cell_value(value)
    return "NULL" if value.nil?
    return value.strftime("%Y-%m-%d %H:%M:%S") if value.respond_to?(:strftime)

    value.to_s
  end
end
