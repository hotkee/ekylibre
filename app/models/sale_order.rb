# == Schema Information
#
# Table name: sale_orders
#
#  accounted           :boolean       not null
#  amount              :decimal(16, 2 default(0.0), not null
#  amount_with_taxes   :decimal(16, 2 default(0.0), not null
#  annotation          :text          
#  client_id           :integer       not null
#  comment             :text          
#  company_id          :integer       not null
#  conclusion          :text          
#  confirmed_on        :date          
#  contact_id          :integer       
#  created_at          :datetime      not null
#  created_on          :date          not null
#  creator_id          :integer       
#  currency_id         :integer       
#  delivery_contact_id :integer       
#  downpayment_amount  :decimal(16, 2 default(0.0), not null
#  expiration_id       :integer       not null
#  expired_on          :date          not null
#  function_title      :string(255)   
#  has_downpayment     :boolean       not null
#  id                  :integer       not null, primary key
#  introduction        :text          
#  invoice_contact_id  :integer       
#  invoiced            :boolean       not null
#  letter_format       :boolean       default(TRUE), not null
#  lock_version        :integer       default(0), not null
#  nature_id           :integer       not null
#  number              :string(64)    not null
#  parts_amount        :decimal(16, 2 
#  payment_delay_id    :integer       not null
#  responsible_id      :integer       
#  state               :string(1)     default("O"), not null
#  subject             :string(255)   
#  sum_method          :string(8)     default("wt"), not null
#  transporter_id      :integer       
#  updated_at          :datetime      not null
#  updater_id          :integer       
#

class SaleOrder < ActiveRecord::Base
  belongs_to :client, :class_name=>Entity.to_s
  belongs_to :company
  belongs_to :contact
  belongs_to :currency
  belongs_to :delivery_contact,:class_name=>Contact.to_s
  belongs_to :expiration, :class_name=>Delay.to_s
  belongs_to :invoice_contact, :class_name=>Contact.to_s
  belongs_to :nature, :class_name=>SaleOrderNature.to_s
  belongs_to :payment_delay, :class_name=>Delay.to_s
  belongs_to :responsible, :class_name=>Employee.name
  has_many :deliveries, :foreign_key=>:order_id
  has_many :invoices
  has_many :lines, :class_name=>SaleOrderLine.to_s, :foreign_key=>:order_id
  has_many :payment_parts, :as=>:expense
  has_many :stock_moves, :as=>:origin
  has_many :subscriptions, :class_name=>Subscription.to_s

  attr_readonly :company_id, :created_on, :number

  @@natures = [:estimate, :order, :invoice]
  
  def before_validation
    self.parts_amount = self.payment_parts.sum(:amount)||0
    if self.number.blank?
      last = self.company.sale_orders.find(:first, :order=>"number desc")
      self.number = last ? last.number.succ! : '00000001'
    end
    if self.contact.nil?
      dc = self.client.default_contact
      self.contact_id = dc.id if dc
    end
    self.delivery_contact_id ||= self.contact_id
    self.invoice_contact_id  ||= self.delivery_contact_id
    self.created_on ||= Date.today
    if self.nature
      self.expiration_id ||= self.nature.expiration_id 
      self.expired_on ||= self.expiration.compute(self.created_on)
      self.payment_delay_id ||= self.nature.payment_delay_id 
      self.has_downpayment = self.nature.downpayment if self.has_downpayment.nil?
      self.downpayment_amount ||= self.amount_with_taxes*self.nature.downpayment_rate if self.amount_with_taxes>=self.nature.downpayment_minimum
    end

    self.sum_method = 'wt'
    if 1 # wt
      self.amount = 0
      self.amount_with_taxes = 0
      for line in self.lines
        self.amount += line.amount
        self.amount_with_taxes += line.amount_with_taxes
      end
    end

    # Set state to 'Complete' if all is paid
    if self.amount_with_taxes>0 and self.parts_amount == self.amount_with_taxes and self.invoices.sum(:amount_with_taxes) == self.amount_with_taxes
      self.state = 'C'
    elsif not self.confirmed_on.blank? or self.invoices.size>0 #  or self.parts_amount>0
      self.state = 'A'
    else
      self.state = 'E'
    end
    true
  end
  
  def before_validation_on_create
    self.created_on = Date.today
  end

  def after_validation_on_create
    specific_numeration = self.company.parameter("management.sale_orders.numeration").value
    self.number = specific_numeration.next_value unless specific_numeration.nil?
  end
  
  def after_create
    self.client.add_event(:sale_order, self.updater_id)
    true
  end

  def refresh
    self.save
  end

  
  # Confirm the sale order. This permits to reserve stocks before ship.
  # This method don't verify the stock moves.
  def confirm(validated_on=Date.today)
    if self.estimate? and self.confirmed_on.nil?
      for line in self.lines.find(:all, :conditions=>["quantity>0"])
        line.product.reserve_stock(line.quantity, :location_id=>line.location_id, :planned_on=>self.created_on, :origin=>self)
      end
      self.reload.update_attributes!(:confirmed_on=>validated_on||Date.today, :state=>"A")
    end
  end

  ## Create the real stock moves when no deliveries are defined (invoice directly)
  def move_real_stocks
    if self.deliveries.size > 0
      for line in self.lines
        line.product.take_stock_out(line.undelivered_quantity, :location_id=>line.location_id, :planned_on=>self.created_on, :origin=>self)
      end
    else
      for line in self.lines
        line.product.take_stock_out(line.quantity, :location_id=>line.location_id, :planned_on=>self.created_on, :origin=>self)
      end
    end
  end
  

  # Create the last delivery with undelivered products if necessary.
  # The sale order is confirmed if it hasn't be done.
  def deliver
    self.confirm
    lines = []
    for line in self.lines.find_all_by_reduction_origin_id(nil)
      if quantity = line.undelivered_quantity > 0
        #raise Exception.new quantity.inspect+line.inspect
        #lines << {:order_line_id=>line.id, :quantity=>quantity, :company_id=>self.company_id}
        lines << {:order_line_id=>line.id, :quantity=>line.quantity, :company_id=>self.company_id}
      end
    end
    if lines.size>0
      delivery = self.deliveries.create!(:amount=>0, :amount_with_taxes=>0, :company_id=>self.company_id, :planned_on=>Date.today, :moved_on=>Date.today, :contact_id=>self.delivery_contact_id)
      for line in lines
        delivery.lines.create! line
      end
      self.refresh
    end
    self
  end


  # Invoice all the products creating the delivery if necessary. 
  def invoice
    self.confirm
    self.reload
    puts self.undelivered(:amount).inspect+"LLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL"
    #return false if self.undelivered(:amount) > 0
   # raise Exception.new "3"
    
    invoice = self.invoices.create!(:company_id=>self.company_id, :nature=>"S", :amount=>self.amount, :amount_with_taxes=>self.amount_with_taxes, :client_id=>self.client_id, :payment_delay_id=>self.payment_delay_id, :created_on=>Date.today, :contact_id=>self.invoice_contact_id)
    for line in self.lines
      invoice.lines.create!(:company_id=>line.company_id, :order_line_id=>line.id, :amount=>line.amount, :amount_with_taxes=>line.amount_with_taxes, :quantity=>line.quantity)
    end
    # accountize the matching invoice.
    if self.company.parameter('accountancy.to_accountancy.automatic')
      invoice.to_accountancy if self.company.parameter('accountancy.to_accountancy.automatic').value == 'true'
    end
    
    self.invoiced = true
    self.save!
  end


  # Delivers all undelivered products and invoice the order after. This operation cleans the order.
  def deliver_and_invoice
    self.deliver.invoice
  end

  # Duplicates a +sale_order+ in 'E' mode with its lines and its active subscriptions
  def duplicate(attributes={})
    fields = [:client_id, :nature_id, :currency_id, :letter_format, :annotation, :subject, :function_title, :introduction, :conclusion, :comment]
    hash = {}
    fields.each{|c| hash[c] = self.send(c)}
    copy = self.company.sale_orders.build(attributes.merge(hash))
    copy.save!
    if copy.save
      # Lines
      for line in self.lines.find(:all, :conditions=>["quantity>0"])
        copy.lines.create! :order_id=>copy.id, :product_id=>line.product_id, :quantity=>line.quantity, :location_id=>line.location_id, :company_id=>self.company_id
      end
      # Subscriptions
      for sub in self.subscriptions.find(:all, :conditions=>["NOT suspended"])
        copy.subscriptions.create!(:sale_order_id=>copy.id, :entity_id=>sub.entity_id, :contact_id=>sub.contact_id, :quantity=>sub.quantity, :nature_id=>sub.nature_id, :product_id=>sub.product_id, :company_id=>self.company_id)
      end
    else
      raise Exception.new(copy.errors.inspect)
    end
    copy
  end



  # Produces some amounts about the sale order.
  # Some options can be used:
  # - +:multi_invoices+ adds the uninvoiced amount and invoiced amount
  # - +:with_balance+ adds the balance of the client of the sale order
  def stats(options={})
    invoiced = self.invoiced_amount
    array = []
    array << [:client_balance, self.client.balance.to_s] if options[:with_balance]
    array << [:total_amount, self.amount_with_taxes]
    if options[:multi_invoices]
      array << [:uninvoiced_amount, self.amount_with_taxes - invoiced]
      array << [:invoiced_amount, invoiced]
    end
    array << [:paid_amount, paid = self.payment_parts.sum(:amount)]
    array << [:unpaid_amount, invoiced - paid]
    array 
  end


  def self.natures
    @@natures.collect{|x| [tc('natures.'+x.to_s), x] }
  end

  def text_state
    tc('states.'+self.state.to_s)
  end


  # Computes an amount (with or without taxes) of the undelivered products
  # - +column+ can be +:amount+ or +:amount_with_taxes+
  def undelivered(column)
    sum  = self.send(column)
    sum -= DeliveryLine.sum(column, :joins=>"JOIN deliveries ON (delivery_id=deliveries.id)", :conditions=>["deliveries.order_id=?", self.id])
    sum.round(2)
  end


  # Computes unpaid amounts.
  def unpaid_amount(only_invoices=true, only_received_payments=false)
    (only_invoices ? self.invoiced_amount : self.amount_with_taxes).to_f - (only_received_payments ? self.payment_parts.sum(:amount, :conditions=>{:received=>true}) : self.payment_parts.sum(:amount)).to_f
  end

  def invoiced_amount
    self.invoices.sum(:amount_with_taxes)
  end
  

  def payments
    sale_orders = self.client.sale_orders
    payment_parts = [] 
    for sale_order in sale_orders
      payment_parts += sale_order.payment_parts
    end
    payments = []
    for part in payment_parts
      found = false
      pay = self.company.payments.find(:all, :conditions=>["id = ? AND amount != part_amount", part.payment_id])
      if !pay.empty? 
        for payment in payments
          found = true if payment.id == pay[0].id 
        end
        payments += pay if (!pay.nil? and !found)
        puts payments.inspect
      end
    end
    payments
  end


  def status
    status = ""
    status = "critic" if self.active? and self.parts_amount.to_f < self.amount_with_taxes
    status
  end


  def label
    tc('label.'+(self.estimate? ? 'estimate' : 'order'), :number=>self.number)
  end

  
  def estimate?
    self.state == 'E'
  end

  def active?
    self.state == 'A'
  end

  def complete?
    self.state == 'C'
  end


  def letter?
    self.letter_format and self.estimate? 
  end

  def need_check?
    self.letter? and self.nature.payment_type == "check"
  end

  def address
    a = self.client.full_name+"\n"
    a += (self.contact ? self.contact.address : self.client.default_contact.address).gsub(/\s*\,\s*/, "\n")
    a
  end

  def number_label
    tc("number_label."+(self.estimate? ? 'proposal' : 'command'), :number=>self.number)
  end

  def taxes
    self.amount_with_taxes - self.amount
  end

  def payment_entity_id
    self.client.id
  end

  def usable_payments
    # self.company.payments.find(:all, :conditions=>["COALESCE(parts_amount,0)<COALESCE(amount,0) AND entity_id = ?" , self.payment_entity_id], :order=>"created_at desc")
    self.company.payments.find(:all, :conditions=>["COALESCE(parts_amount, 0)<COALESCE(amount,0)"], :order=>"amount")
  end

  # Build general sales condition for the sale order
  def sales_conditions
    c = []
    c << tc('sales_conditions.downpayment', :percent=>100*self.nature.downpayment_rate, :amount=>(self.nature.downpayment_rate*self.amount_with_taxes).round(2)) if self.amount_with_taxes>self.nature.downpayment_minimum
    c << tc('sales_conditions.validity', :expiration=>::I18n.localize(self.expired_on, :format=>:legal))
    c += self.company.sales_conditions.to_s.split(/\s*\n\s*/)
    c += self.responsible.department.sales_conditions.to_s.split(/\s*\n\s*/) if self.responsible
    c
  end

  def last_payment
    self.client.payments.find(:first, :order=>"paid_on desc")
  end
  
  #this method accountizes the sale.
  def to_accountancy #(record_id, currency_id)
    self.update_attribute(:accounted, true)
    #journal_sale=  self.company.journals.find(:first, :conditions => ['nature = ?', 'sale'], :order=>:id)
    
    #financialyear = self.company.financialyears.find(:first, :conditions => ["(? BETWEEN started_on and stopped_on) and closed=?", '%'+Date.today.to_s+'%', false])

    #financialyear = self.company.financialyears.find(:first, :conditions => ["(? BETWEEN started_on and stopped_on) AND closed=?", '%'+Date.today.to_s+'%', true])
    
    
    #record = self.company.journal_records.create!(:resource_id=>self.id, :resource_type=>'sale', :created_on=>Date.today, :printed_on => self.created_on, :journal_id=>journal_sale.id, :financialyear_id => financialyear.id)
    
    
    #if self.client.client_account_id.nil?
     #  self.client.reload.update_attribute(:client_account_id, self.client.create_update_account(:client).id)
    #end

    # if the sale contains a downpayment
    # if self.has_downpayment
#       account_downpayment = self.company.accounts.find(self.client.client_account_id).number
#       account = self.company.accounts.find(:first, :conditions =>{:number=>account_downpayment.insert(2, '9').to_s})
#       if account.nil?
#         account = self.company.accounts.create!(:name=>"Clients, avances et acomptes reçus", :number=>account_downpayment, :company_id=>self.company.id)
#       end
          
#       entry = self.company.entries.create!(:record_id=>record_id, :account_id=>account.id, :name=>account.name, :currency_debit=>0.0, :currency_credit=>self.downpayment_amount, :currency_id=>currency_id)
#     end
      
    #entry = self.company.entries.create!(:record_id=>record_id, :account_id=>self.client.client_account_id, :name=>self.client.full_name, :currency_debit=>self.amount_with_taxes, :currency_credit=>0.0, :currency_id=>currency_id,:draft=>true)
    
    # self.lines.each do |line|
#       line_amount = (line.amount * line.quantity)
#       entry = self.company.entries.create!(:record_id=>record_id, :account_id=>line.product.product_account_id, :name=>'sale '+line.product.name.to_s, :currency_debit=>0.0, :currency_credit=>line_amount, :currency_id=>currency_id,:draft=>true)
#       unless line.price.tax_id.nil?
#         line_amount_tax = line.price.tax.amount*line_amount
#         entry = self.company.entries.create!(:record_id=>record_id, :account_id=>line.price.tax.account_collected_id, :name=>line.price.tax.name, :currency_debit=>0.0, :currency_credit=>line_amount_tax, :currency_id=>currency_id,:draft=>true) unless line_amount_tax.zero?
#       end
#      end
    
    
    # all payments of the company matching to this sale and comptabilization.
   #  payments = self.company.payments.find(:all, :conditions => ["i.sale_order_id = ? and payments.accounted=?", self.id, false] , :joins=>"inner join payment_parts p on p.payment_id=payments.id and p.expense_type='#{SaleOrder.name}' inner join invoices i on i.id=p.invoice_id")
    

#     payments.each do |payment|
#       if payment.embankment
#         payment.to_accountancy 
#         payment.update_attribute(:accounted, true)
#       end
#     end
    
  end
  

end


