require "cgi"
require "digest"
require "json"
require "net/http"
require "stringio"
require "zlib"
require_relative "comparison_support"

# Expected result windows come from the seed, independently of the implementation.
module BenchmarkContracts
  extend BenchmarkSupport
  def self.prepare(base, cookie, database, labels, css, destination)
    room = Integer(labels.fetch("rooms.watercooler"))
    write_room = Integer(labels.fetch("rooms.hq"))
    uri = URI(base)
    sql = ->(db, query) do
      output = run("sqlite3", "-cmd", ".timeout 10000", "-readonly", "-json", db, query)
      output.strip.empty? ? [] : JSON.parse(output)
    end
    routes = { "room_show" => "/rooms/#{room}", "messages_page" => "/rooms/#{room}/messages?before=#{labels.fetch('messages.busy_060')}",
      "sidebar" => "/users/me/sidebar", "search" => "/searches?q=coffee", "avatar" => "/users/#{labels.fetch('avatar_tokens.jason')}/avatar",
      "static_css" => css, "up" => "/up", "post_message" => nil }
    preflight = {}
    contracts = {}
    anchor = Integer(labels.fetch('messages.busy_060'))
    expected_db_ids = {
      "room_show" => sql.call(database, "SELECT id FROM messages WHERE room_id=#{room} ORDER BY created_at DESC LIMIT 40").map { |v| v.fetch("id") }.reverse,
      "messages_page" => sql.call(database, "SELECT id FROM messages WHERE room_id=#{room} AND created_at < (SELECT created_at FROM messages WHERE id=#{anchor}) ORDER BY created_at DESC LIMIT 40").map { |v| v.fetch("id") }.reverse,
      "search" => sql.call(database, "SELECT m.id FROM messages m JOIN message_search_index idx ON idx.rowid=m.id JOIN memberships mm ON mm.room_id=m.room_id JOIN users u ON u.id=mm.user_id WHERE u.email_address='#{labels.fetch('emails.david').gsub("'", "''")}' AND idx.body MATCH 'coffee' ORDER BY m.id DESC LIMIT 100").map { |v| v.fetch("id") }.reverse
    }
    contract_dir = destination
    FileUtils.mkdir_p(contract_dir)
    Net::HTTP.new(uri.host, uri.port, nil).start do |http|
      routes.each do |name, path|
        next unless path
        response = http.get(path, "Cookie" => cookie, "Accept-Encoding" => "gzip")
        raise "#{name}: HTTP #{response.code}" unless response.code == "200"
        body = response.body
        body = Zlib::GzipReader.new(StringIO.new(body)).read if response["content-encoding"] == "gzip"
        raise "#{name}: empty body" if body.empty?
        raise "#{name}: unpopulated" if %w[room_show messages_page search].include?(name) && !body.match?(/data-message-id="\d+"/)
        raise "sidebar missing room" if name == "sidebar" && !(body.include?("shared_rooms") && body.include?(room.to_s))
        raise "invalid avatar" if name == "avatar" && !(response["content-type"].start_with?("image/") && body.bytesize > 100)
        raise "invalid CSS" if name == "static_css" && !(response["content-type"].start_with?("text/css") && body.include?("{"))
        raise "invalid health" if name == "up" && !body.include?("background-color: green")
        if %w[room_show messages_page search].include?(name)
          ids = body.scan(/data-message-id="(\d+)"/).flatten.map(&:to_i)
          raise "#{name}: differs from seed SQL" unless ids == expected_db_ids.fetch(name)
        end
        if %w[room_show sidebar search].include?(name)
          raise "#{name}: incomplete HTML page" unless body.match?(/<!doctype html>/i) && body.include?("</html>")
        end
        contract = { kind: name, content_type: response["content-type"].split(";").first, required: [], message_ids: nil }
        if %w[room_show messages_page search].include?(name)
          contract[:message_ids] = ids
          bodies = sql.call(database, "SELECT rowid AS id, body FROM message_search_index WHERE rowid IN (#{ids.join(',')})").to_h { |v| [v.fetch("id"), v.fetch("body")] }
          contract[:message_content] = ids.map { |id| bodies.fetch(id).scan(/[A-Za-z0-9_]{3,}/).max_by(&:length).to_s }
          contract[:required] = sql.call(database, "SELECT id, client_message_id FROM messages WHERE id IN (#{ids.join(',')})").map do |v|
            markers = ["id=\"message_#{v.fetch('id')}\"", "id=\"message_#{v.fetch('client_message_id')}\""]
            markers.find { |marker| body.include?(marker) } || raise("missing message DOM identity #{v.fetch('id')}")
          end
        elsif name == "sidebar"
          contract[:required] = ["shared_rooms"]
          # A valid sidebar must retain all seeded, visible room names.
          contract[:required] += sql.call(database, "SELECT r.name FROM rooms r JOIN memberships m ON m.room_id=r.id JOIN users u ON u.id=m.user_id WHERE u.email_address='#{labels.fetch('emails.david').gsub("'", "''")}' AND r.type='Rooms::Open' AND m.involvement<>'invisible'").map { |v| CGI.escapeHTML(v.fetch("name")) }
        elsif %w[avatar static_css].include?(name)
          contract[:exact_body] = body.bytes
        elsif name == "up"
          contract[:required] = ["background-color: green"]
        end
        contracts[name] = File.join(contract_dir, "#{name}.json")
        write_json(contracts[name], contract)
        preflight[name] = { message_ids: %w[room_show messages_page search].include?(name) ? ids : nil, decoded_bytes: body.bytesize, wire_bytes: response.body.bytesize,
          body_sha256: Digest::SHA256.hexdigest(body), encoding: response["content-encoding"], content_type: response["content-type"] }
      end
    end
    write_page = Net::HTTP.new(uri.host, uri.port, nil).start { |http| http.get("/rooms/#{write_room}", "Cookie" => cookie, "Accept-Encoding" => "identity") }
    raise "write room inaccessible" unless write_page.code == "200" && write_page.body.include?("</html>")
    write_targets = write_page.body.scan(/id="(messages_[^"]+)"/).flatten.select { |id| id.match?(/\Amessages_(?:rooms_[a-z]+|room)_#{write_room}\z/) }
    raise "missing or ambiguous write-room DOM target" unless write_targets.size == 1
    contracts["post_message"] = File.join(contract_dir, "post_message.json")
    write_json(contracts["post_message"], kind: "post_message", content_type: "text/vnd.turbo-stream.html", required: ["action=\"append\"", "target=\"#{write_targets.first}\""])
    { contracts: contracts, preflight: preflight }
  end
end

if $PROGRAM_NAME == __FILE__
  base, cookie, database, labels, css, destination = ARGV
  puts JSON.generate(BenchmarkContracts.prepare(base, cookie, database, JSON.parse(File.read(labels)), css, destination))
end
