defmodule Campfire.Sounds do
  import Kernel, except: [sigil_r: 2]
  import Campfire.Sigils
  alias Campfire.Assets
  @external_resource "vectors/sounds.json"
  @sounds Jason.decode!(File.read!(@external_resource))
          |> Map.new(&{&1["name"], Map.drop(&1, ["presentation"])})

  def find(plain) do
    case Regex.run(~r/\A\/play (?<name>\w+)\z/u, plain) do
      [_, name] -> @sounds[name]
      _ -> nil
    end
  end

  def render(sound) do
    display =
      if image = sound["image"] do
        ~s(<img width="#{image["width"]}" height="#{image["height"]}" class="align--middle" src="#{Assets.path(image["asset_path"])}" />)
      else
        Assets.html_escape(sound["text"])
      end

    ~s(<div class="sound" data-controller="sound" data-action="messages:play-&gt;sound#play" data-sound-url-value="#{Assets.path(sound["asset_path"])}"><button class="btn btn--plain" data-action="sound#play">🔊</button>#{display}</div>)
  end
end
