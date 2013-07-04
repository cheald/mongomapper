require 'spec_helper'

describe "Scopes" do
  context "Scopes" do
    before do
      @document = Doc() do
        key :name, String
        key :age, Integer
        timestamps!
      end
    end

    let(:bill)  { @document.create(:name => 'Bill',  :age => 10) }
    let(:frank) { @document.create(:name => 'Frank', :age => 15) }
    let(:john)  { @document.create(:name => 'John',  :age => 99) }
    let(:todd)  { @document.create(:name => 'Todd',  :age => 65) }

    def make_people
      john; frank; bill; todd
    end

    context "scopes without a callable" do
      subject {
        lambda {
          @document.class_eval {
            scope :old, :age.gt => 90
          }
        }
      }

      context "under Rails 4" do
        it "should raise a deprecation notice" do
          ActiveSupport::Deprecation.should_receive(:warn).once
          subject.call
        end
      end if rails4?

      context "under Rails 3" do
        it "should not raise a deprecation notice" do
          ActiveSupport::Deprecation.should_not_receive(:warn)
          subject.call
        end
      end unless rails4?
    end

    context "basic scopes" do
      before do
        @document.class_eval do
          scope :old, lambda {{ :age.gt => 90 }}
          scope :teens, lambda {{ :age.gte => 13, :age.lte => 19 }}
        end
      end

      it "should know what scopes have been added" do
        @document.scopes.keys.should =~ [:old, :teens]
      end

      it "should return a plucky query" do
        @document.old.should be_kind_of(Plucky::Query)
      end

      specify { make_people; @document.old.all.should == [john] }
    end

    context "scopes given only the name" do
      before do
        @document.instance_eval do
          def old
            {:age.gt => 90}
          end

          def old_returning_query
            where(:age.gt => 90)
          end
        end

        @document.class_eval do
          scope :old
          scope :old_returning_query
        end
      end

      it "should return a plucky query" do
        @document.old.should be_kind_of(Plucky::Query)
      end

      it "should return a plucky query" do
        @document.old_returning_query.should be_kind_of(Plucky::Query)
      end

      specify { make_people; @document.old.all.should == [john] }
      specify { make_people; @document.old_returning_query.all.should == [john] }
    end

    context "dynamic scopes" do
      before do
        @document.class_eval do
          scope :age,     lambda { |age| {:age => age} }
          scope :ages,    lambda { |low, high| {:age.gte => low, :age.lte => high} }
          scope :ordered, lambda { |sort| sort(sort) }
        end
        make_people
      end

      it "should work with single argument" do
        @document.age(john.age).all.should == [john]
      end

      it "should work with multiple arguments" do
        @document.ages(frank.age - 1, john.age + 1).all.should =~ [frank, todd, john]
      end

      it "should work with queries" do
        @document.ordered(:age).all.should == [bill, frank, todd, john]
      end
    end

    context "query scopes" do
      before do
        @document.class_eval do
          scope :boomers, lambda { where(:age.gte => 60).sort(:age) }
        end
        make_people
      end

      it "should work" do
        @document.boomers.all.should =~ [john, todd]
      end
    end

    context "chaining" do
      before do
        @document.class_eval do
          scope :by_age,  lambda { |age| {:age => age} }
          scope :by_name, lambda { |name| {:name => name} }
        end
        make_people
      end

      it "should work with scope methods" do
        @document.by_age(99).by_name('John').all.should == [john]
      end

      it "should work on query methods" do
        @document.where(:name => 'John').by_age(99).all.should == [john]
      end

      context "with model methods" do
        it "should work if method returns a query" do
          young_john = @document.create(:name => 'John', :age => 10)
          @document.class_eval do
            def self.young
              query(:age.lte => 12)
            end
          end

          @document.by_name('John').all.should =~ [john, young_john]
          @document.by_name('John').young.all.should == [young_john]
        end

        it "should not work if method does not return a query" do
          @document.class_eval { def self.age; 20 end }
          @document.by_name('John').age.should == 20
        end
      end
    end

    context "with single collection inheritance" do
      before do
        class ::Item
          include MongoMapper::Document
          scope :by_title,  lambda { |title| {:title => title} }
          scope :published, lambda { {:published_at.lte => Time.now.utc} }

          key   :title, String
          key   :published_at, Time
        end
        Item.collection.remove

        class ::Page < ::Item; end
        class ::Blog < ::Item
          key :slug, String
          scope :by_slug, lambda { |slug| {:slug => slug} }
        end
      end

      after do
        Object.send :remove_const, 'Item' if defined?(::Item)
        Object.send :remove_const, 'Page' if defined?(::Page)
        Object.send :remove_const, 'Blog' if defined?(::Blog)
      end

      it "should inherit scopes" do
        Page.scopes.keys.map(&:to_s).sort.should == %w(by_title published)
      end

      it "should work with _type" do
        item = Item.create(:title => 'Home')
        page = Page.create(:title => 'Home')
        Page.by_title('Home').first.should == page
      end

      it "should limit subclass scopes to subclasses" do
        Item.scopes.keys.map(&:to_s).should =~ %w(by_title published)
        Blog.scopes.keys.map(&:to_s).should =~ %w(by_slug by_title published)
      end
    end
  end
end
