ActiveRecord::Schema.define :version => 0 do

  create_table :people, :force => true do |t|
    t.integer :id
    t.string  :name
    t.date    :birthday
    t.float   :height
  end

  create_table :stores, :force => true do |t|
    t.integer :id
    t.string  :name
    t.integer :owner_id
  end

  create_table :people_stores, :id => false, :force => true do |t|
    t.integer :person_id
    t.string  :store_id
  end

  create_table :apples, :force => true do |t|
    t.integer :id
    t.string  :name
    t.integer :store_id
    t.integer :person_id
  end

  create_table :bananas, :force => true do |t|
    t.integer :id
    t.string  :name
    t.integer :store_id
    t.integer :person_id
  end

  create_table :pears, :force => true do |t|
    t.integer :id
    t.string  :name
    t.integer :store_id
    t.integer :person_id
  end

  create_table :addresses, :force => true do |t|
    t.integer :id
    t.string  :name
    t.integer :store_id
  end

end
