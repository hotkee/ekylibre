# == Schema Information
# Schema version: 20090311124450
#
# Table name: sale_orders
#
#  id                  :integer       not null, primary key
#  client_id           :integer       not null
#  nature_id           :integer       not null
#  created_on          :date          not null
#  number              :string(64)    not null
#  sum_method          :string(8)     default("wt"), not null
#  invoiced            :boolean       not null
#  amount              :decimal(16, 2 default(0.0), not null
#  amount_with_taxes   :decimal(16, 2 default(0.0), not null
#  state               :string(1)     default("O"), not null
#  expiration_id       :integer       not null
#  expired_on          :date          not null
#  payment_delay_id    :integer       not null
#  has_downpayment     :boolean       not null
#  downpayment_amount  :decimal(16, 2 default(0.0), not null
#  contact_id          :integer       not null
#  invoice_contact_id  :integer       not null
#  delivery_contact_id :integer       not null
#  subject             :string(255)   
#  function_title      :string(255)   
#  introduction        :text          
#  conclusion          :text          
#  comment             :text          
#  company_id          :integer       not null
#  created_at          :datetime      not null
#  updated_at          :datetime      not null
#  created_by          :integer       
#  updated_by          :integer       
#  lock_version        :integer       default(0), not null
#

class SaleOrder < ActiveRecord::Base
  attr_readonly :company_id, :created_on, :number

  def before_validation
    if self.number.blank?
      last = self.client.sale_orders.find(:first, :order=>"number desc")
      self.number = if last
                      last.number.succ!
                    else
                      '00000001'
                    end
    end
    self.created_on ||= Date.today
    if self.nature
      self.expiration_id ||= self.nature.expiration_id 
      self.expired_on ||= self.expiration.compute(self.created_on)
      self.payment_delay_id ||= self.nature.payment_delay_id 
      if self.has_downpayment.nil?
        self.has_downpayment = self.nature.downpayment
      end
      
      self.downpayment_amount ||= self.amount_with_taxes*self.nature.downpayment_rate if self.amount_with_taxes>=self.nature.downpayment_minimum
    end

    if 1 # wt
      self.amount = 0
      self.amount_with_taxes = 0
      for line in self.lines
        self.amount += line.amount
        self.amount_with_taxes += line.amount_with_taxes
      end
    else
      
    end

  end

  def before_validation_on_create
    self.created_on = Date.today
  end

  def refresh
    self.save
  end


  def self.natures
    [:estimate, :order, :invoice].collect{|x| [tc('natures.'+x.to_s), x] }
  end

  def undelivered(column)
    sum = 0
    if column == "amount"
      for line in self.lines
        sum += line.price.amount*line.undelivered_quantity
      end
    elsif column == "amount_with_taxes"
       for line in self.lines
        sum += line.price.amount_with_taxes*line.undelivered_quantity
       end
    end
    sum
  end

  def add_payment(payment)
    rest_to_pay = PaymentPart.sum(:amount, :conditions=>{:order_id=>self.id,:company_id=>self.company_id})
    if payment.amount > rest_to_pay
      PaymentPart.create!(:amount=>rest_to_pay,:order_id=>self.id,:company_id=>self.company_id,:payment_id=>payment.id)
      payment.update_attributes(:part_amount=>rest_to_pay)
    end
    rest_to_pay
  end

end
