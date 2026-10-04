# Generated from vectors/schema.json; pinned Rails 90b330024dec3e757c79b6a7e6568f93da8e3148.
defmodule Campfire.Generated.AccountsRow do
  @moduledoc "Storage-shaped record; callbacks and timestamp/JSON codecs remain app-owned."
  defstruct [
    :id,
    :created_at,
    :custom_styles,
    :join_code,
    :name,
    :settings,
    :singleton_guard,
    :updated_at
  ]

  def table, do: "accounts"
  def primary_key, do: "id"

  def columns,
    do: [
      %{
        "name" => "id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "created_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "custom_styles",
        "type" => "text",
        "sql_type" => "TEXT",
        "null" => true,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "join_code",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "name",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "settings",
        "type" => "json",
        "sql_type" => "json",
        "null" => true,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "singleton_guard",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => 0,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "updated_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      }
    ]
end

defmodule Campfire.Generated.ActionTextRichTextsRow do
  @moduledoc "Storage-shaped record; callbacks and timestamp/JSON codecs remain app-owned."
  defstruct [:id, :body, :created_at, :name, :record_id, :record_type, :updated_at]
  def table, do: "action_text_rich_texts"
  def primary_key, do: "id"

  def columns,
    do: [
      %{
        "name" => "id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "body",
        "type" => "text",
        "sql_type" => "TEXT",
        "null" => true,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "created_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "name",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "record_id",
        "type" => "integer",
        "sql_type" => "bigint",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "record_type",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "updated_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      }
    ]
end

defmodule Campfire.Generated.ActiveStorageAttachmentsRow do
  @moduledoc "Storage-shaped record; callbacks and timestamp/JSON codecs remain app-owned."
  defstruct [:id, :blob_id, :created_at, :name, :record_id, :record_type]
  def table, do: "active_storage_attachments"
  def primary_key, do: "id"

  def columns,
    do: [
      %{
        "name" => "id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "blob_id",
        "type" => "integer",
        "sql_type" => "bigint",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "created_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "name",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "record_id",
        "type" => "integer",
        "sql_type" => "bigint",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "record_type",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      }
    ]
end

defmodule Campfire.Generated.ActiveStorageBlobsRow do
  @moduledoc "Storage-shaped record; callbacks and timestamp/JSON codecs remain app-owned."
  defstruct [
    :id,
    :byte_size,
    :checksum,
    :content_type,
    :created_at,
    :filename,
    :key,
    :metadata,
    :service_name
  ]

  def table, do: "active_storage_blobs"
  def primary_key, do: "id"

  def columns,
    do: [
      %{
        "name" => "id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "byte_size",
        "type" => "integer",
        "sql_type" => "bigint",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "checksum",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => true,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "content_type",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => true,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "created_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "filename",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "key",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "metadata",
        "type" => "text",
        "sql_type" => "TEXT",
        "null" => true,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "service_name",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      }
    ]
end

defmodule Campfire.Generated.ActiveStorageVariantRecordsRow do
  @moduledoc "Storage-shaped record; callbacks and timestamp/JSON codecs remain app-owned."
  defstruct [:id, :blob_id, :variation_digest]
  def table, do: "active_storage_variant_records"
  def primary_key, do: "id"

  def columns,
    do: [
      %{
        "name" => "id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "blob_id",
        "type" => "integer",
        "sql_type" => "bigint",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "variation_digest",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      }
    ]
end

defmodule Campfire.Generated.ArInternalMetadataRow do
  @moduledoc "Storage-shaped record; callbacks and timestamp/JSON codecs remain app-owned."
  defstruct [:key, :value, :created_at, :updated_at]
  def table, do: "ar_internal_metadata"
  def primary_key, do: "key"

  def columns,
    do: [
      %{
        "name" => "key",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "value",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => true,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "created_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "updated_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      }
    ]
end

defmodule Campfire.Generated.BansRow do
  @moduledoc "Storage-shaped record; callbacks and timestamp/JSON codecs remain app-owned."
  defstruct [:id, :created_at, :ip_address, :updated_at, :user_id]
  def table, do: "bans"
  def primary_key, do: "id"

  def columns,
    do: [
      %{
        "name" => "id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "created_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "ip_address",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "updated_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "user_id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      }
    ]
end

defmodule Campfire.Generated.BoostsRow do
  @moduledoc "Storage-shaped record; callbacks and timestamp/JSON codecs remain app-owned."
  defstruct [:id, :booster_id, :content, :created_at, :message_id, :updated_at]
  def table, do: "boosts"
  def primary_key, do: "id"

  def columns,
    do: [
      %{
        "name" => "id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "booster_id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "content",
        "type" => "string",
        "sql_type" => "varchar(16)",
        "null" => false,
        "default" => nil,
        "limit" => 16,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "created_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "message_id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "updated_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      }
    ]
end

defmodule Campfire.Generated.MembershipsRow do
  @moduledoc "Storage-shaped record; callbacks and timestamp/JSON codecs remain app-owned."
  defstruct [
    :id,
    :connected_at,
    :connections,
    :created_at,
    :involvement,
    :room_id,
    :unread_at,
    :updated_at,
    :user_id
  ]

  def table, do: "memberships"
  def primary_key, do: "id"

  def columns,
    do: [
      %{
        "name" => "id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "connected_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => true,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "connections",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => 0,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "created_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "involvement",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => true,
        "default" => "mentions",
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "room_id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "unread_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => true,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "updated_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "user_id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      }
    ]
end

defmodule Campfire.Generated.MessagesRow do
  @moduledoc "Storage-shaped record; callbacks and timestamp/JSON codecs remain app-owned."
  defstruct [:id, :client_message_id, :created_at, :creator_id, :room_id, :updated_at]
  def table, do: "messages"
  def primary_key, do: "id"

  def columns,
    do: [
      %{
        "name" => "id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "client_message_id",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "created_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "creator_id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "room_id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "updated_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      }
    ]
end

defmodule Campfire.Generated.PushSubscriptionsRow do
  @moduledoc "Storage-shaped record; callbacks and timestamp/JSON codecs remain app-owned."
  defstruct [
    :id,
    :auth_key,
    :created_at,
    :endpoint,
    :p256dh_key,
    :updated_at,
    :user_agent,
    :user_id
  ]

  def table, do: "push_subscriptions"
  def primary_key, do: "id"

  def columns,
    do: [
      %{
        "name" => "id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "auth_key",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => true,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "created_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "endpoint",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => true,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "p256dh_key",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => true,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "updated_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "user_agent",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => true,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "user_id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      }
    ]
end

defmodule Campfire.Generated.RoomsRow do
  @moduledoc "Storage-shaped record; callbacks and timestamp/JSON codecs remain app-owned."
  defstruct [:id, :created_at, :creator_id, :name, :type, :updated_at]
  def table, do: "rooms"
  def primary_key, do: "id"

  def columns,
    do: [
      %{
        "name" => "id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "created_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "creator_id",
        "type" => "integer",
        "sql_type" => "bigint",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "name",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => true,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "type",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "updated_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      }
    ]
end

defmodule Campfire.Generated.SchemaMigrationsRow do
  @moduledoc "Storage-shaped record; callbacks and timestamp/JSON codecs remain app-owned."
  defstruct [:version]
  def table, do: "schema_migrations"
  def primary_key, do: "version"

  def columns,
    do: [
      %{
        "name" => "version",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      }
    ]
end

defmodule Campfire.Generated.SearchesRow do
  @moduledoc "Storage-shaped record; callbacks and timestamp/JSON codecs remain app-owned."
  defstruct [:id, :created_at, :query, :updated_at, :user_id]
  def table, do: "searches"
  def primary_key, do: "id"

  def columns,
    do: [
      %{
        "name" => "id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "created_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "query",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "updated_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "user_id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      }
    ]
end

defmodule Campfire.Generated.SessionsRow do
  @moduledoc "Storage-shaped record; callbacks and timestamp/JSON codecs remain app-owned."
  defstruct [
    :id,
    :created_at,
    :ip_address,
    :last_active_at,
    :token,
    :updated_at,
    :user_agent,
    :user_id
  ]

  def table, do: "sessions"
  def primary_key, do: "id"

  def columns,
    do: [
      %{
        "name" => "id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "created_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "ip_address",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => true,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "last_active_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "token",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "updated_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "user_agent",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => true,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "user_id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      }
    ]
end

defmodule Campfire.Generated.UsersRow do
  @moduledoc "Storage-shaped record; callbacks and timestamp/JSON codecs remain app-owned."
  defstruct [
    :id,
    :bio,
    :bot_token,
    :created_at,
    :email_address,
    :name,
    :password_digest,
    :role,
    :status,
    :updated_at
  ]

  def table, do: "users"
  def primary_key, do: "id"

  def columns,
    do: [
      %{
        "name" => "id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "bio",
        "type" => "text",
        "sql_type" => "TEXT",
        "null" => true,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "bot_token",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => true,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "created_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "email_address",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => true,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "name",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "password_digest",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => true,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "role",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => 0,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "status",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => 0,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "updated_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      }
    ]
end

defmodule Campfire.Generated.WebhooksRow do
  @moduledoc "Storage-shaped record; callbacks and timestamp/JSON codecs remain app-owned."
  defstruct [:id, :created_at, :updated_at, :url, :user_id]
  def table, do: "webhooks"
  def primary_key, do: "id"

  def columns,
    do: [
      %{
        "name" => "id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "created_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "updated_at",
        "type" => "datetime",
        "sql_type" => "datetime(6)",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => 6,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "url",
        "type" => "string",
        "sql_type" => "varchar",
        "null" => true,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      },
      %{
        "name" => "user_id",
        "type" => "integer",
        "sql_type" => "INTEGER",
        "null" => false,
        "default" => nil,
        "limit" => nil,
        "precision" => nil,
        "scale" => nil,
        "unsigned" => false,
        "array" => false
      }
    ]
end
