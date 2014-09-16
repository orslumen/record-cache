# encoding: utf-8
require 'spec_helper'

describe 'ActiveRecord Visitor' do

  def find_visit_methods(visitor_class)
    (visitor_class.instance_methods + visitor_class.private_instance_methods).select{ |method| method.to_s =~ /^visit_Arel_/ }.sort.uniq
  end

  it 'should implement all visitor methods' do
    all_visit_methods = find_visit_methods(Arel::Visitors::ToSql)
    rc_visit_methods = find_visit_methods(RecordCache::Arel::QueryVisitor)
    expect(all_visit_methods - rc_visit_methods).to be_empty
  end

  it 'should not implement old visitor methods' do
    all_visit_methods = find_visit_methods(Arel::Visitors::ToSql)
    rc_visit_methods = find_visit_methods(RecordCache::Arel::QueryVisitor)
    expect(rc_visit_methods - all_visit_methods).to be_empty
  end

end
