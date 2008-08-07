require 'lucene/query_dsl'


# TODO DRY
require 'fileutils'  

require 'lucene'

include Lucene

$INDEX_DIR = 'var/index'


def delete_all_indexes
  FileUtils.rm_r $INDEX_DIR if File.directory? $INDEX_DIR
end

describe Lucene::QueryDSL, 'used from Index.find' do
  
  before(:each) do
    delete_all_indexes
    @index = Index.new($INDEX_DIR)    
    @index.clear
    @index.field_infos[:value][:type] = Fixnum
    @index << {:id => '42', :name => 'andreas', :foo => 'bar', :value => 1}
    @index << {:id => '43', :name => 'andreas', :foo => 'baaz', :value => 2}    
    @index << {:id => '44', :name => 'x', :foo => 'bar', :value => 3}        
    @doc1 = @index.uncommited['42']
    @doc2 = @index.uncommited['43']
    @doc3 = @index.uncommited['44']
    @index.commit
  end

  it "should find a document using a simple dsl query" do
    hits = @index.find { name == 'andreas'}
    
    hits.size.should == 2
    hits.should include(@doc1, @doc2)
  end

  it "should find a document using a compound | expression" do
    hits = @index.find { (name == 'andreas') | (name == 'x')}
    hits.size.should == 3
    hits.should include(@doc1, @doc2, @doc3)
    
    hits = @index.find { (name == 'andreasx') | (name == 'x')}
    hits.size.should == 1
    hits.should include(@doc3)
    
  end

  it "should find with Range" do
    hits = @index.find { value == 2..9 }
    hits.size.should == 2
    hits.should include(@doc2, @doc3)
  end

  it "should find with Range in a compound expression " do
    hits = @index.find { (name == 'andreas') & (value == 2..9) }
    hits.size.should == 1
    hits.should include(@doc2)
  end

  
  it "should find with a compound & expression" do
    hits = @index.find { (name == 'andreas') & (foo == 'bar')}
    
    hits.size.should == 1
    hits.should include(@doc1)
  end
  
end

describe Lucene::QueryDSL do

  it "should parse & expressions" do
    expr = Lucene::QueryDSL.parse{ (name == 'andreas') & (age == 30)}
    expr.op.should == :&
    expr.left.left.should == :name
    expr.left.right.should == 'andreas'
    
    expr.right.left.should == :age
    expr.right.right.should == 30
  end

  it "should parse | expressions" do
    expr = Lucene::QueryDSL.parse{ (name == 'andreas') | (age == 30)}
    expr.op.should == :|
    expr.left.left.should == :name
    expr.left.right.should == 'andreas'
    
    expr.right.left.should == :age
    expr.right.right.should == 30
  end

  it "should parse range expressions" do
    expr = Lucene::QueryDSL.parse{ name == 1..3}
    
    expr.left.should == :name
    expr.right.should be_kind_of(Range)
    expr.right.first.should == 1
    expr.right.last.should == 3
  end
  
  it "should generate a lucene query" do
    expr = Lucene::QueryDSL.parse{ name == 'andreas' }
    query = expr.to_lucene(Lucene::FieldInfos.new(:id))
    
    query.should be_kind_of(Java::OrgApacheLuceneSearch::TermQuery)
    term = query.getTerm
    term.field.should == 'name'
    term.text.should == 'andreas'
  end

  
  it "should generate a lucene query" do
    expr = Lucene::QueryDSL.parse{ (name == 'andreas') & (age == 1) }
    query = expr.to_lucene(Lucene::FieldInfos.new(:id))
    
    query.should be_kind_of(Java::OrgApacheLuceneSearch::BooleanQuery)
        
    clauses = query.getClauses() 
    clauses.size.should == 2
    
    term0 = clauses[0].getQuery.getTerm
    term0.field.should == 'name'
    term0.text.should == 'andreas'

    term1 = clauses[1].getQuery.getTerm
    term1.field.should == 'age'
    term1.text.should == '1'
  end
  
end

