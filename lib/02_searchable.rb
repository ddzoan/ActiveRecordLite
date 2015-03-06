require_relative 'db_connection'
require_relative '01_sql_object'

module Searchable
  def where(params)
    values = params.values
    where_line = params.keys.map { |attribute| "#{attribute} = ?" }.join(' AND ')

    search = <<-SQL
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        #{where_line}
    SQL

    parse_all(DBConnection.execute(search, *values))
  end
end

class SQLObject
  extend Searchable
end
