# Forward definition of Markov handler class
class Lita::Handlers::Markov < Lita::Handler; end

require 'lita/handlers/markov/engine'

module Lita::Handlers
  class Markov
    attr_reader :engine

    config :database_url
    
    route(/.+/, :ingest, command: false)

    route(/markov (.+)/, :generate, command: true, help: {
      'markov USER' => 'Generate a markov chain from the given user.'
    })

    def initialize(robot)
      super(robot)

      @engine = Engine.new self
    end

    def ingest(chat)
      # Don't ingest messages addressed to ourselves
      return if chat.command?

      message = chat.matches[0].strip

      # Get the mention name (ie. 'dirk') of the user
      id = chat.user.id

      @engine.ingest id, message
    end

    def generate(chat)
      name = chat.matches[0][0].strip
      id   = Lita::User.fuzzy_find(name).id

      begin
        sentence = @engine.generate_sentence_for id

        chat.reply sentence
      rescue Engine::EmptyDictionaryError
        chat.reply "Looks like #{name} hasn't said anything!"
      end
    end

    def save_dictionary(name, dictionary)
      redis.set key_for_user(name), dictionary.to_json
    end

    def dictionary_for_user(name)
      key        = key_for_user name
      dictionary = Dictionary.new name
      json       = redis.get key

      dictionary.load_json(json) if json

      dictionary
    end

    def key_for_user(name)
      REDIS_KEY_PREFIX+name.downcase
    end

    Lita.register_handler self
  end
end
