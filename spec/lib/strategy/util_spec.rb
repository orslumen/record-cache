# encoding: utf-8
require 'spec_helper'

describe RecordCache::Strategy::Util do

  it "should serialize a record (currently Active Record only)" do
    subject.serialize(Banana.find(1)).should == {:a=>{"name"=>"Blue Banana 1", "id"=>1, "store_id"=>2, "person_id"=>4}, :c=>"Banana"}
  end

  it "should deserialize a record (currently Active Record only)" do
    subject.deserialize({:a=>{"name"=>"Blue Banana 1", "id"=>1, "store_id"=>2, "person_id"=>4}, :c=>"Banana"}).should == Banana.find(1)
  end

  it "should call the after_finalize and after_find callbacks when deserializing a record" do
    record = subject.deserialize({:a=>{"name"=>"Blue Banana 1", "id"=>1, "store_id"=>2, "person_id"=>4}, :c=>"Banana"})
    record.logs.sort.should == ["after_find", "after_initialize"]
  end

  it "should not be a new record nor have changed attributes after deserializing a record" do
    record = subject.deserialize({:a=>{"id"=>1}, :c=>"Banana"})
    record.new_record?.should be_false
    record.changed_attributes.should be_empty
  end

  context "filter" do
    it "should apply filter" do
      apples = Apple.where(:id => [1,2]).all
      subject.filter!(apples, :name => "Adams Apple 1")
      apples.should == [Apple.find_by_name("Adams Apple 1")]
    end

    it "should return empty array when filter does not match any record" do
      apples = Apple.where(:id => [1,2]).all
      subject.filter!(apples, :name => "Adams Apple Pie")
      apples.should be_empty
    end

    it "should filter on text" do
      apples = Apple.where(:id => [1,2]).all
      subject.filter!(apples, :name => "Adams Apple 1")
      apples.should == [Apple.find_by_name("Adams Apple 1")]
    end

    it "should filter on integers" do
      apples = Apple.where(:id => [1,2,8,9]).all
      subject.filter!(apples, :store_id => 2)
      apples.map(&:id).sort.should == [8,9]
    end

    it "should filter on dates" do
      people = Person.where(:id => [1,2,3]).all
      subject.filter!(people, :birthday => Date.civil(1953,11,11))
      people.size.should == 1
      people.first.name.should == "Blue"
    end

    it "should filter on floats" do
      people = Person.where(:id => [1,2,3]).all
      subject.filter!(people, :height => 1.75)
      people.size.should == 2
      people.map(&:name).sort.should == ["Blue", "Cris"]
    end

    it "should filter on arrays" do
      apples = Apple.where(:id => [1,2,8,9])
      subject.filter!(apples, :store_id => [2, 4])
      apples.map(&:id).sort.should == [8,9]
    end

    it "should filter on multiple fields" do
      # make sure two apples exist with the same name
      apple = Apple.find(8)
      apple.name = Apple.find(9).name
      apple.save!

      apples = Apple.where(:id => [1,2,3,8,9,10]).all
      subject.filter!(apples, :store_id => [2, 4], :name => apple.name)
      apples.size.should == 2
      apples.map(&:name).should == [apple.name, apple.name]
      apples.map(&:id).sort.should == [8,9]
    end

  end

  context "sort" do
    it "should accept a Symbol as a sort order" do
      people = Person.where(:id => [1,2,3]).all
      subject.sort!(people, :name)
      people.map(&:name).should == ["Adam", "Blue", "Cris"]
    end

   it "should accept a single Array as a sort order" do
      people = Person.where(:id => [1,2,3]).all
      subject.sort!(people, [:name, false])
      people.map(&:name).should == ["Cris", "Blue", "Adam"]
    end

    it "should accept multiple Symbols as a sort order" do
      people = Person.where(:id => [2,3,4,5]).all
      subject.sort!(people, :height, :id)
      people.map(&:height).should == [1.69, 1.75, 1.75, 1.91]
      people.map(&:id).should == [4, 2, 3, 5]
    end

    it "should accept a mix of Symbols and Arrays as a sort order" do
      people = Person.where(:id => [2,3,4,5]).all
      subject.sort!(people, [:height, false], :id)
      people.map(&:height).should == [1.91, 1.75, 1.75, 1.69]
      people.map(&:id).should == [5, 2, 3, 4]
    end

    it "should accept multiple Arrays as a sort order" do
      people = Person.where(:id => [2,3,4,5]).all
      subject.sort!(people, [:height, false], [:id, false])
      people.map(&:height).should == [1.91, 1.75, 1.75, 1.69]
      people.map(&:id).should == [5, 3, 2, 4]
    end

    it "should accept an Array with Arrays as a sort order (default used by record cache)" do
      people = Person.where(:id => [2,3,4,5]).all
      subject.sort!(people, [[:height, false], [:id, false]])
      people.map(&:height).should == [1.91, 1.75, 1.75, 1.69]
      people.map(&:id).should == [5, 3, 2, 4]
    end

    it "should order nil first for ASC" do
      apples = Apple.where(:store_id => 1).all
      subject.sort!(apples, [:person_id, true])
      apples.map(&:person_id).should == [nil, nil, 4, 4, 5]
    end

    it "should order nil last for DESC" do
      apples = Apple.where(:store_id => 1).all
      subject.sort!(apples, [:person_id, false])
      apples.map(&:person_id).should == [5, 4, 4, nil, nil]
    end

    it "should order ascending on text" do
      people = Person.where(:id => [1,2,3,4]).all
      subject.sort!(people, [:name, true])
      people.map(&:name).should == ["Adam", "Blue", "Cris", "Fry"]
    end

    it "should order descending on text" do
      people = Person.where(:id => [1,2,3,4]).all
      subject.sort!(people, [:name, false])
      people.map(&:name).should == ["Fry", "Cris", "Blue", "Adam"]
    end

    it "should order ascending on integers" do
      people = Person.where(:id => [4,2,1,3]).all
      subject.sort!(people, [:id, true])
      people.map(&:id).should == [1,2,3,4]
    end

    it "should order descending on integers" do
      people = Person.where(:id => [4,2,1,3]).all
      subject.sort!(people, [:id, false])
      people.map(&:id).should == [4,3,2,1]
    end

    it "should order ascending on dates" do
      people = Person.where(:id => [1,2,3,4]).all
      subject.sort!(people, [:birthday, true])
      people.map(&:birthday).should == [Date.civil(1953,11,11), Date.civil(1975,03,20), Date.civil(1975,03,20), Date.civil(1985,01,20)]
    end

    it "should order descending on dates" do
      people = Person.where(:id => [1,2,3,4]).all
      subject.sort!(people, [:birthday, false])
      people.map(&:birthday).should == [Date.civil(1985,01,20), Date.civil(1975,03,20), Date.civil(1975,03,20), Date.civil(1953,11,11)]
    end

    it "should order ascending on float" do
      people = Person.where(:id => [1,2,3,4]).all
      subject.sort!(people, [:height, true])
      people.map(&:height).should == [1.69, 1.75, 1.75, 1.83]
    end

    it "should order descending on float" do
      people = Person.where(:id => [1,2,3,4]).all
      subject.sort!(people, [:height, false])
      people.map(&:height).should == [1.83, 1.75, 1.75, 1.69]
    end

    it "should order on multiple fields (ASC + ASC)" do
      people = Person.where(:id => [2,3,4,5]).all
      subject.sort!(people, [:height, true], [:id, true])
      people.map(&:height).should == [1.69, 1.75, 1.75, 1.91]
      people.map(&:id).should == [4, 2, 3, 5]
    end

    it "should order on multiple fields (ASC + DESC)" do
      people = Person.where(:id => [2,3,4,5]).all
      subject.sort!(people, [:height, true], [:id, false])
      people.map(&:height).should == [1.69, 1.75, 1.75, 1.91]
      people.map(&:id).should == [4, 3, 2, 5]
    end

    it "should order on multiple fields (DESC + ASC)" do
      people = Person.where(:id => [2,3,4,5]).all
      subject.sort!(people, [:height, false], [:id, true])
      people.map(&:height).should == [1.91, 1.75, 1.75, 1.69]
      people.map(&:id).should == [5, 2, 3, 4]
    end

    it "should order on multiple fields (DESC + DESC)" do
      people = Person.where(:id => [2,3,4,5]).all
      subject.sort!(people, [:height, false], [:id, false])
      people.map(&:height).should == [1.91, 1.75, 1.75, 1.69]
      people.map(&:id).should == [5, 3, 2, 4]
    end

    it "should use mysql style collation" do
      ids = []
      ids << Person.create!(:name => "ċedriĉ 3").id # latin other special
      ids << Person.create!(:name => "a cedric").id # first in ascending order
      ids << Person.create!(:name => "čedriĉ 4").id # latin another special
      ids << Person.create!(:name => "ćedriĉ Last").id # latin special lowercase
      ids << Person.create!(:name => "sedric 1").id # second to last latin in ascending order
      ids << Person.create!(:name => "Cedric 2").id # ascii uppercase
      ids << Person.create!(:name => "čedriĉ คฉ Almost last cedric").id # latin special, with non-latin
      ids << Person.create!(:name => "Sedric 2").id # last latin in ascending order
      ids << Person.create!(:name => "1 cedric").id # numbers before characters
      ids << Person.create!(:name => "cedric 1").id # ascii lowercase
      ids << Person.create!(:name => "คฉ Really last").id # non-latin characters last in ascending order
      ids << Person.create!(:name => "čedriĉ ꜩ Last").id # latin special, with latin non-collateable

      names_asc = ["1 cedric", "a cedric", "cedric 1", "Cedric 2", "ċedriĉ 3", "čedriĉ 4", "ćedriĉ Last", "čedriĉ คฉ Almost last cedric", "čedriĉ ꜩ Last", "sedric 1", "Sedric 2",  "คฉ Really last"]
      people = Person.where(:id => ids).all
      subject.sort!(people, [:name, true])
      people.map(&:name).should == names_asc

      subject.sort!(people, [:name, false])
      people.map(&:name).should == names_asc.reverse
    end
  end

end
