# Read the app's current distribution state using the existing Codemagic integration.
require "openssl"
require "base64"
require "json"
require "net/http"
require "uri"

def encode(data)
  Base64.urlsafe_encode64(data, padding: false)
end

now = Time.now.to_i
header = { alg: "ES256", kid: ENV.fetch("APP_STORE_CONNECT_KEY_IDENTIFIER"), typ: "JWT" }
claims = { iss: ENV.fetch("APP_STORE_CONNECT_ISSUER_ID"), aud: "appstoreconnect-v1", iat: now, exp: now + 600 }
message = [header, claims].map { |value| encode(JSON.generate(value)) }.join(".")
material = ENV.fetch("APP_STORE_CONNECT_PRIVATE_KEY").strip
if material.start_with?("@file:")
  material = File.binread(material.delete_prefix("@file:"))
elsif material.start_with?("/") && File.file?(material)
  material = File.binread(material)
elsif !material.include?("-----BEGIN")
  material = Base64.strict_decode64(material.gsub(/\s+/, ""))
end
key = OpenSSL::PKey.read(material.gsub('\n', "\n"))
der = key.sign("SHA256", message)
signature = OpenSSL::ASN1.decode(der).value.map { |integer| integer.value.to_s(2).rjust(32, "\0") }.join
token = message + "." + encode(signature)

get = lambda do |path, query|
  uri = URI("https://api.appstoreconnect.apple.com/v1/" + path)
  uri.query = URI.encode_www_form(query)
  response = Net::HTTP.get_response(uri, { "Authorization" => "Bearer " + token })
  body = JSON.parse(response.body)
  abort("App Store Connect #{response.code}: " + Array(body["errors"]).map { |e| e["code"] }.join(", ")) unless response.is_a?(Net::HTTPSuccess)
  body
end

app_id = "6827530890"
groups = get.call("apps/#{app_id}/betaGroups", {"limit" => "200", "fields[betaGroups]" => "name,isInternalGroup,publicLinkEnabled,publicLink"})
groups.fetch("data").each do |group|
  info = group.fetch("attributes")
  puts "Group #{info["name"]} | #{info["isInternalGroup"] ? "internal" : "external"} | public link #{info["publicLinkEnabled"] == true ? "on" : "off"}"
  if info["publicLinkEnabled"] && info["name"] == "好友体验测试"
    puts "TestFlight invitation: #{info["publicLink"]}"
  end
end
builds = get.call("builds", { "filter[app]" => app_id, "sort" => "-uploadedDate", "limit" => "5", "include" => "betaGroups,buildBetaDetail" })
included = builds.fetch("included", []).to_h { |item| [[item["type"], item["id"]], item.fetch("attributes", {})] }
builds.fetch("data").each do |build|
  rel = build.fetch("relationships")
  details = rel.dig("buildBetaDetail", "data") || {}
  status = included.fetch([details["type"], details["id"]], {})
  names = Array(rel.dig("betaGroups", "data")).map { |g| included.dig([g["type"], g["id"]], "name") }.compact
  puts "Build #{build.dig("attributes", "version")} | #{build.dig("attributes", "processingState")} | internal #{status["internalBuildState"]} | external #{status["externalBuildState"]} | groups #{names.join(", ")}"
end
