# Run with the immutable reference bundle through bin/rails runner.
puts JSON.generate(Sound::BUILTIN.map { |sound|
  message = Message.new(body: "/play #{sound.name}")
  { name: sound.name, text: sound.text, asset_path: sound.asset_path,
    image: sound.image && { asset_path: sound.image.asset_path, width: sound.image.width, height: sound.image.height },
    presentation: ApplicationController.helpers.message_presentation(message) }
})
