require 'spec_helper'

describe "WithPersistenceOptions" do
  let(:document) {
    Doc do
      key :first_name, String
      key :last_name, String
      key :age, Integer
      key :date, Date
    end
  }

  before do
    document.connection["test_alternate"]["classes"].drop
    document.connection["test"]["test_alternate"].drop
    document.connection["test_alternate"]["test_alternate"].drop
  end

  describe "#with" do
    it "should return a QueryProxy" do
      document.with(:database => "alternate").should be_a MongoMapper::Plugins::WithPersistenceOptions::QueryProxy
    end
  end

  describe "#marshal_dump" do
    it "should not include override keys" do
      document.with(:db => :foo, :coll => :bar).create.tap do |doc|
        doc.instance_variables.map(&:to_sym).should include :@__collection
        doc.instance_variables.map(&:to_sym).should include :@__database
        doc.marshal_dump.keys.should_not include([:@__collection, :@__database])
      end
    end

    it "should retain its origin DB after being dumped and loaded" do
      NamedDocument = document
      doc = NamedDocument.with(:db => :test_alternate, :coll => :test_alternate).create
      reconstituted_doc = Marshal.load(Marshal.dump(doc))
      reconstituted_doc.database.name.should == "test_alternate"
      reconstituted_doc.database.name.should == "test_alternate"
      reconstituted_doc.first_name = "I LIVE"
      reconstituted_doc.save
      NamedDocument.connection["test_alternate"]["test_alternate"].find_one().should == doc.attributes.merge("first_name" => "I LIVE")
    end
  end

  describe "DecoratedPluckyQuery" do
    describe "#with" do
      it "should return a DecoratedPluckyQuery" do
        query = document.where
        query.should be_a MongoMapper::Plugins::Querying::DecoratedPluckyQuery

        query.with(:db => "foobar").should be_a MongoMapper::Plugins::Querying::DecoratedPluckyQuery
      end

      it "should have an overridden database name" do
      end

      it "should have an overridden collection name" do
      end

      context "when data exists" do
        let(:scoped_document) { document.where.with(:database => "test_alternate", :collection => "test_alternate") }

        before do
          document.with(:database => "test_alternate", :collection => "test_alternate").create(:first_name => "Alternate", :last_name => "DB")
        end

        it "should be a DecoratedPluckyQuery" do
          scoped_document.should be_a MongoMapper::Plugins::Querying::DecoratedPluckyQuery
        end

        it "should have the correct database name" do
          scoped_document.database.name.should == "test_alternate"
        end

        it "should have the correct collection name" do
          scoped_document.collection.name.should == "test_alternate"
        end

        before do
          scoped_document.create :first_name => "Alternate", :last_name => "DB"
          document.create :first_name => "Default", :last_name => "DB"
        end

        describe "#first" do
          it "should find a document in the alternate DB and collection" do
            scoped_document.first.first_name.should == "Alternate"
          end
        end
      end
    end
  end

  describe "QueryProxy" do
    describe "#create" do
      it "should create the document in an alternate database" do
        doc = document.with(:database => "test_alternate").create(:first_name => "Chris", :last_name => "Heald")
        document.connection["test_alternate"]["classes"].find_one().should == doc.attributes
      end

      it "should create the document in an alternate collection" do
        doc = document.with(:collection => "test_alternate").create(:first_name => "Chris", :last_name => "Heald")
        document.connection["test"]["test_alternate"].find_one().should == doc.attributes
      end

      it "should create the document in an alternate collection and database" do
        doc = document.with(:database => "test_alternate", :collection => "test_alternate").create(:first_name => "Chris", :last_name => "Heald")
        document.connection["test_alternate"]["test_alternate"].find_one().should == doc.attributes
      end
    end

    describe "#new" do
      it "should create the document in an alternate database" do
        doc = document.with(:database => "test_alternate").new(:first_name => "Chris", :last_name => "Heald")
        doc.save
        document.connection["test_alternate"]["classes"].find_one().should == doc.attributes
      end

      it "should create the document in an alternate collection" do
        doc = document.with(:collection => "test_alternate").new(:first_name => "Chris", :last_name => "Heald")
        doc.save
        document.connection["test"]["test_alternate"].find_one().should == doc.attributes
      end

      it "should create the document in an alternate collection and database" do
        doc = document.with(:database => "test_alternate", :collection => "test_alternate").new(:first_name => "Chris", :last_name => "Heald")
        doc.save
        document.connection["test_alternate"]["test_alternate"].find_one().should == doc.attributes
      end
    end

    describe "#create" do
      it "should create the document in an alternate database" do
        doc = document.with(:database => "test_alternate").create!(:first_name => "Chris", :last_name => "Heald")
        document.connection["test_alternate"]["classes"].find_one().should == doc.attributes
      end

      it "should create the document in an alternate collection" do
        doc = document.with(:collection => "test_alternate").create!(:first_name => "Chris", :last_name => "Heald")
        document.connection["test"]["test_alternate"].find_one().should == doc.attributes
      end

      it "should create the document in an alternate collection and database" do
        doc = document.with(:database => "test_alternate", :collection => "test_alternate").create!(:first_name => "Chris", :last_name => "Heald")
        document.connection["test_alternate"]["test_alternate"].find_one().should == doc.attributes
      end
    end

    context "when data exists" do
      let(:scoped_document) { document.with(:database => "test_alternate", :collection => "test_alternate")}

      before do
        scoped_document.create :first_name => "Alternate", :last_name => "DB"
        document.create :first_name => "Default", :last_name => "DB"
      end

      describe "#first" do
        it "should find a document in the alternate DB and collection" do
          scoped_document.first.first_name.should == "Alternate"
        end

        it "should not affect the default document" do
          document.first.first_name.should == "Default"
        end
      end

      describe "#where" do
        it "should find a document in the alternate DB and collection" do
          scoped_document.where(:first_name => "Alternate").first.first_name.should == "Alternate"
          scoped_document.where(:first_name => "Default").first.should be_nil
        end

        it "should not affect the default document" do
          document.where(:first_name => "Alternate").first.should be_nil
          document.where(:first_name => "Default").first.first_name.should == "Default"
        end
      end

      describe "#save" do
        it "should save to the DB the document was loaded from" do
          doc = scoped_document.first
          doc.first_name = "Updated Alternate"
          doc.save

          scoped_document.first.first_name.should == "Updated Alternate"
        end
      end

      describe "#reload" do
        it "should reload from the same DB it was loaded from" do
          scoped_document.first.first_name.should == scoped_document.first.reload.first_name
        end
      end
    end
  end
end