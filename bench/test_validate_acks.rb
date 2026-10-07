require "minitest/autorun"
require "tmpdir"
require_relative "validate_acks"

class AcknowledgedWritesTest < Minitest::Test
  def test_rejects_duplicate_acks_missing_body_wrong_room_and_missing_index
    Dir.mktmpdir do |folder|
      database = File.join(folder, "data.db")
      _, errors, status = Open3.capture3("sqlite3", database, <<~SQL)
        CREATE TABLE messages(id INTEGER PRIMARY KEY,room_id INTEGER);
        CREATE TABLE action_text_rich_texts(record_type TEXT,name TEXT,record_id INTEGER,body TEXT);
        CREATE VIRTUAL TABLE message_search_index USING fts5(body);
        INSERT INTO messages VALUES(42,1);
        INSERT INTO action_text_rich_texts VALUES('Message','body',42,'bench write abc');
        INSERT INTO message_search_index(rowid,body) VALUES(42,'bench write abc');
      SQL
      assert status.success?, errors
      audit = File.join(folder, "acks.jsonl")
      row = { "id" => 42, "token" => "bench write abc" }
      File.write(audit, JSON.generate(row) + "\n")
      assert_equal({ "verified" => true, "acknowledged" => 1 }, AcknowledgedWrites.verify(database, 1, [audit], 1))
      assert_raises(RuntimeError) { AcknowledgedWrites.verify(database, 2, [audit], 1) }
      assert_raises(RuntimeError) { AcknowledgedWrites.verify(database, 1, [audit], 2) }
      File.write(audit, (JSON.generate(row) + "\n") * 2)
      assert_raises(RuntimeError) { AcknowledgedWrites.verify(database, 1, [audit], 2) }
      File.write(audit, JSON.generate({ "id" => 42, "token" => "bench write def" }) + "\n")
      assert_raises(RuntimeError) { AcknowledgedWrites.verify(database, 1, [audit], 1) }
      File.write(audit, JSON.generate(row) + "\n")
      _, errors, status = Open3.capture3("sqlite3", database, "DELETE FROM message_search_index;")
      assert status.success?, errors
      assert_raises(RuntimeError) { AcknowledgedWrites.verify(database, 1, [audit], 1) }
    end
  end
end
