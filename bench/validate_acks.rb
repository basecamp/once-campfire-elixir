require "json"
require "open3"
require "tempfile"

module AcknowledgedWrites
  def self.verify(database, room, files, expected)
    rows = files.flat_map { |path| File.foreach(path).map { |line| JSON.parse(line) } }
    raise "Wrong acknowledgement count" unless rows.size == expected
    raise "Invalid acknowledgement" unless rows.all? { |row| row["id"].is_a?(Integer) && row["id"] > 0 && /\Abench write [0-9a-f]+\z/.match?(row["token"].to_s) }
    raise "A message was acknowledged more than once" unless rows.map { |row| row.fetch("id") }.uniq.size == rows.size
    raise "Request bodies were not unique" unless rows.map { |row| row.fetch("token") }.uniq.size == rows.size

    Tempfile.create(["campfire-write-audit-", ".json"]) do |file|
      file.write(JSON.generate(rows))
      file.flush
      query = <<~SQL
        WITH acknowledged AS MATERIALIZED (
          SELECT json_extract(value, '$.id') AS id, json_extract(value, '$.token') AS token
          FROM json_each(readfile('#{file.path.gsub("'", "''")}'))
        )
        SELECT COUNT(*) AS valid FROM acknowledged a CROSS JOIN messages m
        WHERE m.id=a.id
        AND m.room_id=#{Integer(room)}
        AND EXISTS(SELECT 1 FROM action_text_rich_texts rt WHERE rt.record_type='Message'
          AND rt.name='body' AND rt.record_id=m.id AND instr(rt.body,a.token)>0)
        AND EXISTS(SELECT 1 FROM message_search_index idx
          WHERE idx.rowid=m.id AND instr(idx.body,a.token)>0)
      SQL
      output, errors, status = Open3.capture3("sqlite3", "-cmd", ".timeout 10000", "-readonly", "-json", database, query)
      raise "Cannot verify writes: #{errors}" unless status.success?
      valid = JSON.parse(output).first.fetch("valid")
      raise "#{expected - valid} acknowledged messages lack their exact body or search entry" unless valid == expected
    end
    { "verified" => true, "acknowledged" => expected }
  end
end

if $PROGRAM_NAME == __FILE__
  database, room, expected, *files = ARGV
  puts JSON.generate(AcknowledgedWrites.verify(database, room, files, Integer(expected)))
end
