if RUBY_VERSION >= '1.9'
  require 'csv'
  ::RemoteTable::CSV = ::CSV
else
  begin
    require 'fastercsv'
    ::RemoteTable::CSV = ::FasterCSV
  rescue ::LoadError
    $stderr.puts "[remote_table] You probably need to manually install the fastercsv gem and/or require it in your Gemfile."
    raise $!
  end
end

class RemoteTable
  class Format
    class Delimited < Format
      include Textual
      def each(&blk)
        remove_useless_characters!
        fix_newlines!
        transliterate_whole_file_to_utf8!
        skip_rows!
        CSV.new(t.local_file.encoded_io, fastercsv_options).each do |row|
          if row.is_a?(CSV::Row)
            hash = row.inject(::ActiveSupport::OrderedHash.new) do |memo, (k, v)|
              if k.present?
                memo[k] = v.to_s
              end
              memo
            end
            yield hash if t.properties.keep_blank_rows or hash.any? { |k, v| v.present? }
          elsif row.is_a?(::Array)
            array = row.map { |v| v.to_s }
            yield array if t.properties.keep_blank_rows or array.any? { |v| v.present? }
          end
        end
      ensure
        t.local_file.delete
      end

      private

      FASTERCSV_OPTIONS = %w{
        unconverted_fields
        col_sep
        headers
        row_sep
        return_headers
        header_converters
        quote_char
        skip_blanks
        converters
        force_quotes
      }

      def fastercsv_options
        hsh = t.options.slice *FASTERCSV_OPTIONS
        hsh.merge! 'skip_blanks' => !t.properties.keep_blank_rows
        hsh.reverse_merge! 'headers' => t.properties.headers
        hsh.reverse_merge! 'col_sep' => t.properties.delimiter
        hsh.symbolize_keys
      end
    end
  end
end
