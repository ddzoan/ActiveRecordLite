require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    query = <<-SQL
      SELECT
        *
      FROM
        #{table_name}
    SQL
    table = DBConnection.execute2(query)
    table.first.map(&:to_sym)
  end

  def self.finalize!
    columns.each do |column|
      define_method(column) do
        attributes[column]
      end

      define_method("#{column}=".to_sym) do |value|
        attributes[column] = value
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name ||= self.name.tableize
  end

  def self.all
    query = <<-SQL
      SELECT
        *
      FROM
        #{table_name}
    SQL

    parse_all(DBConnection.execute(query))
  end

  def self.parse_all(results)
    results.map do |result|
      self.new(result)
    end
  end

  def self.find(id)
    query = <<-SQL
      SELECT
        *
      FROM
        #{table_name}
      WHERE
        id = :id
      LIMIT
        1
    SQL

    parse_all(DBConnection.execute(query, id: id)).first
  end

  def initialize(params = {})
    columns = self.class.columns
    params.each do |attr_name, value|
      raise "unknown attribute '#{attr_name}'" unless columns.include?(attr_name.to_sym)
      self.send("#{attr_name}=", value)
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map do |attribute|
      self.send(attribute)
    end
  end

  def insert
    cols_no_id = self.class.columns[1..-1]
    col_names = cols_no_id.join(', ')
    question_marks = (['?'] * (cols_no_id.length)).join(', ')
    insert = <<-SQL
      INSERT INTO
        #{self.class.table_name} (#{col_names})
      VALUES
        (#{question_marks})
    SQL

    new_attribute_values = attribute_values[1..-1]

    DBConnection.execute(insert, *new_attribute_values)
    attributes[:id] = DBConnection.last_insert_row_id
  end

  def update
    set_str = self.class.columns.map { |attribute| "#{attribute} = ?" }.join(', ')
    update = <<-SQL
      UPDATE
        #{self.class.table_name}
      SET
        #{set_str}
      WHERE
        id = #{attributes[:id]}
    SQL

    DBConnection.execute(update, *attribute_values)
  end

  def save
    attributes[:id] ? update : insert
  end
end
