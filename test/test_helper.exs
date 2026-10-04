ExUnit.start()

System.put_env(
  "SECRET_KEY_BASE",
  Jason.decode!(File.read!("vectors/rails_compat.json"))["secret_key_base"]
)
