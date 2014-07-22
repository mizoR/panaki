require "panaki/version"
require 'yaml'

module Panaki
  PANAKI = 'ぱなき'

  def self.root
    File.expand_path('../../', __FILE__)
  end

  def self.data_dir
    File.expand_path('data/', self.root)
  end

  class Base
    class << self
      include Enumerable

      IDENTIFIER_CHARS = (('A'..'Z').to_a + ('0'..'9').to_a - %w(0 1 I O)).freeze

      def generate_identifier
        Array.new(8){ IDENTIFIER_CHARS.sample }.join
      end

      def has_many(association, options={})
        singular_name = association.to_s.slice(0..-2)
        class_name    = singular_name.capitalize
        foreign_key   = options[:foreign_key] || "#{self.name.sub('Panaki::', '').downcase}_id"

        define_method association do
          Object.const_get("Panaki::#{class_name}").select {|instance|
            instance.send(foreign_key) == self.id
          }
        end
      end

      def belongs_to(association)
        class_name = association.to_s.capitalize

        define_method association do
          Object.const_get(class_name).detect {|instance|
            instance.id == self.id
          }
        end
      end

      def each
        @instances ||= []
        @instances.each do |instance|
          yield instance
        end
      end

      def add_instance(instance)
        @instances ||= []
        @instances << instance
      end
    end

    def initialize(*args)
      self.class.add_instance(self)
    end

    def generate_identifier
      self.class.generate_identifier
    end

    def ==(instance)
      super || self.id == instance.id
    end

    def ===(instance)
      super || self.id == instance.id
    end
  end

  class Node < Base
    attr_accessor :id, :word

    has_many :edges, foreign_key: :from

    def initialize(word)
      super

      @id   = generate_identifier
      @word = word
    end

    def nexts
      Node.select { |node|
        edges.map(&:to).include?(node.id)
      }
    end

    def panaki?
      self.word == PANAKI
    end

    def arrow?(node)
      (self.word != node.word) && (self.word[-1] == node.word[0])
    end
  end

  class Edge < Base
    attr_accessor :id, :to, :from

    belongs_to :node

    def initialize(params={})
      super

      @id   = generate_identifier
      @from = params[:from].id
      @to   = params[:to].id
    end
  end

  class Knowledge
    attr_reader :nodes

    def initialize
      @nodes = []
    end

    def <<(node)
      @nodes.select {|_node| node.arrow?(_node)}.each { |to|
        Edge.new(from: node, to: to)
      }

      @nodes.select {|_node| _node.arrow?(node)}.each { |from|
        Edge.new(from: from, to: node)
      }

      @nodes << node
    end
  end

  class AI
    attr_reader :knowledge

    def initialize
      @knowledge = Knowledge.new

      YAML.load_file("#{Panaki.data_dir}/words.yml").each do |word|
        node = Panaki::Node.new(word)
        @knowledge << node
      end
    end

    def hear(word)
      @hear = Panaki::Node.new(word)
      @knowledge << @hear

      self
    end

    def think
      @answer_list = thinking(@hear)

      self
    end

    def pritty_print
      puts answer_string

      self
    end

    def say
      if !answer_string.empty?
        system "say #{answer_string}"
      end

      self
    end

    private

    def thinking(current_node, answer=[], answer_list=[], histories=[])
      case
      when current_node.panaki?
        answer_list << answer + [current_node]
        answer_list
      when histories.include?(current_node)
        answer_list
      when current_node.nexts.empty?
        answer_list
      else
        current_node.nexts.each do |next_node|
          next_answer    = answer + [current_node]
          next_histories = histories + [current_node]
          answer_list    = thinking(next_node, next_answer, answer_list, next_histories)
        end

        answer_list
      end
    end

    def answer_string
      @answer_list.map { |answer|
        answer.map(&:word).join('、')
      }.join("\n")
    end
  end
end
