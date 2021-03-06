# == License
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2008-2011 Brice Texier, Thibaud Merigon
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

class Backend::SalesController < Backend::BaseController
  manage_restfully except: [:index, :show, :new], redirect_to: '{action: :show, id: "id".c}'.c

  respond_to :csv, :ods, :xlsx, :pdf, :odt, :docx, :html, :xml, :json

  unroll :number, :amount, :currency, :created_at, client: :full_name

  # management -> sales_conditions
  def self.sales_conditions
    code = ""
    code = search_conditions(:sales => [:pretax_amount, :amount, :number, :initial_number, :description], :entities => [:number, :full_name]) + " ||= []\n"

    code << "unless params[:s].blank?\n"
    code << "  if params[:s] == 'current'\n"
    code << "    c[0] += \" AND affair_id IN (SELECT id FROM affairs WHERE NOT closed AND credit > 0 AND debit > 0)\"\n"
    code << "  elsif params[:s] == 'unpaid'\n"
    code << "    c[0] += \" AND state IN ('order', 'invoice') AND (payment_at IS NULL OR payment_at <= CURRENT_TIMESTAMP) AND affair_id NOT IN (SELECT id FROM affairs WHERE closed)\"\n"
    code << "  end\n "
    code << "end\n"

    code << "if params[:responsible_id].to_i > 0\n"
    code << "  c[0] += \" AND \#{Sale.table_name}.responsible_id = ?\"\n"
    code << "  c << params[:responsible_id]\n"
    code << "end\n"
    code << "c\n "
    return code.c
  end

  list(conditions: sales_conditions, joins: :client, order: {created_at: :desc, number: :desc}) do |t| # , :line_class => 'RECORD.tags'
    # t.action :show, url: {format: :pdf}, image: :print
    t.action :edit, if: :draft?
    t.action :cancel, if: :cancellable?
    t.action :destroy, if: :aborted?
    t.column :number, url: {action: :show}
    t.column :created_at
    t.column :invoiced_at
    t.column :client, url: true
    t.column :responsible, hidden: true
    t.column :description, hidden: true
    t.status
    t.column :state_label
    t.column :amount, currency: true
  end

  # Displays the main page with the list of sales
  def index
    respond_to do |format|
      format.html
      format.xml  { render :xml => @sales }
      # format.pdf  { render_print_sales(params[:established_at]||Date.today) }
      format.pdf  { render :pdf => @sales, :with => params[:template] }
      # format.odt  { render_print_sales(params[:established_at]||Date.today) }
      # format.docx { render_print_sales(params[:established_at]||Date.today) }
    end
  end

  list(:credits, model: :sales, conditions: {:credited_sale_id => 'params[:id]'.c }, :children => :items) do |t|
    t.column :number, url: true, :children => :designation
    t.column :client, children: false
    t.column :created_at, children: false
    t.column :pretax_amount, currency: true
    t.column :amount, currency: true
  end

  list(:deliveries, model: :outgoing_deliveries, :children => :items, conditions: {:sale_id => 'params[:id]'.c}) do |t|
    t.column :number, :children => :product_name, url: true
    t.column :transporter, children: false, url: true
    t.column :address, label_method: :coordinate, children: false
    t.column :sent_at, children: false, hidden: true
    # t.column :planned_at, children: false
    # t.column :moved_at, children: false
    # t.column :population
    # t.column :pretax_amount, currency: true
    # t.column :amount, currency: true
    t.action :edit, if: :updateable?
    t.action :destroy, if: :destroyable?
  end

  list(:subscriptions, conditions: {:sale_id => 'params[:id]'.c}) do |t|
    t.action :edit
    t.action :destroy
    t.column :number
    t.column :nature
    t.column :subscriber, url: true
    t.column :address
    t.column :start
    t.column :finish
    t.column :quantity
  end

  list(:undelivered_items, model: :sale_items, conditions: {:sale_id => 'params[:id]'.c}) do |t|
    t.column :name, through: :variant
    # t.column :pretax_amount, currency: true, through: :price
    t.column :quantity
    # t.column :unit
    # t.column :pretax_amount, :currency => true
    t.column :amount
    # t.column :undelivered_quantity, :datatype => :decimal
  end

  list(:items, model: :sale_items, conditions: {:sale_id => 'params[:id]'.c}, order: :position, :export => false, :line_class => "((RECORD.variant.subscribing? and RECORD.subscriptions.sum(:quantity) != RECORD.quantity) ? 'warning' : '')".c, :include => [:variant, :subscriptions]) do |t|
    # t.action :edit, if: 'RECORD.sale.draft? and RECORD.reduction_origin_id.nil? '
    # t.action :destroy, if: 'RECORD.sale.draft? and RECORD.reduction_origin_id.nil? '
    # t.column :name, through: :variant
    # t.column :position
    t.column :label
    t.column :annotation, hidden: true
    # t.column :serial_number, through: :variant, url: true
    t.column :quantity
    t.column :unit_name
    t.column :unit_pretax_amount, currency: true
    t.column :unit_amount, currency: true, hidden: true
    t.column :pretax_amount, currency: true
    t.column :amount, currency: true
  end

  # Displays details of one sale selected with +params[:id]+
  def show
    return unless @sale = find_and_check
    @sale.other_deals
    respond_with(@sale, :methods => [:taxes_amount, :affair_closed, :client_number, :sales_conditions, :sales_mentions],
                        :include => {:address => {:methods => [:mail_coordinate]},
                                     :nature => {:include => {:payment_mode => {:include => :cash}}},
                                     :supplier => {:methods => [:picture_path], :include => {:default_mail_address => {:methods => [:mail_coordinate]}, :websites => {}, :emails => {}, :mobiles => {}}},
                                     :credits => {},
                                     :affair => {:methods => [:balance], :include => [:incoming_payments => {:include => :mode}]},
                                     :invoice_address => {:methods => [:mail_coordinate]},
                                     :items => {:methods => [:taxes_amount, :tax_name, :tax_short_label], :include => [:variant]}
                                     }
                                     ) do |format|
      format.html do
        t3e @sale.attributes, client: @sale.client.full_name, state: @sale.state_label, label: @sale.label
      end
    end

  end

  def new
    unless nature = SaleNature.find_by(id: params[:nature_id]) || SaleNature.by_default
      notify_error :need_a_valid_sale_nature_to_start_new_sale
      redirect_to action: :index
      return
    end
    @sale = Sale.new(nature: nature)
    @sale.currency = @sale.nature.currency
    if client = Entity.find_by_id(params[:client_id]||params[:entity_id]||session[:current_entity_id])
      if client.default_mail_address
        cid = client.default_mail_address.id
        @sale.attributes = {address_id: cid, delivery_address_id: cid, invoice_address_id: cid}
      end
    end
    session[:current_entity_id] = (client ? client.id : nil)
    @sale.responsible = current_user.person
    @sale.client_id = session[:current_entity_id]
    @sale.letter_format = false
    @sale.function_title = :default_letter_function_title.tl
    @sale.introduction = :default_letter_introduction.tl
    @sale.conclusion = :default_letter_conclusion.tl
  end

  def duplicate
    return unless @sale = find_and_check
    unless @sale.duplicatable?
      notify_error :sale_is_not_duplicatable
      redirect_to params[:redirect] || {action: :index}
      return
    end
    copy = @sale.duplicate(responsible: current_user.person)
    redirect_to params[:redirect] || {action: :show, id: copy.id}
  end

  def cancel
    return unless @sale = find_and_check
    url = {controller: :sale_credits, action: :new, credited_sale_id: @sale.id}
    url[:redirect] = params[:redirect] if params[:redirect]
    redirect_to url
  end

  def confirm
    return unless @sale = find_and_check
    @sale.confirm
    redirect_to action: :show, id: @sale.id
  end

  def contacts
    if request.xhr?
      client, address_id = nil, nil
      client = if params[:selected] and address = EntityAddress.find_by_id(params[:selected])
                 address.entity
               else
                 Entity.find_by_id(params[:client_id])
               end
      if client
        session[:current_entity_id] = client.id
        address_id = (address ? address.id : client.default_mail_address.id)
      end
      @sale = Sale.find_by_id(params[:sale_id])||Sale.new(:address_id => address_id, :delivery_address_id => address_id, :invoice_address_id => address_id)
      render :partial => 'addresses_form', :locals => {:client => client, :object => @sale}
    else
      redirect_to action: :index
    end
  end

  def abort
    return unless @sale = find_and_check
    @sale.abort
    redirect_to action: :show, id: @sale.id
  end

  def correct
    return unless @sale = find_and_check
    @sale.correct
    redirect_to action: :show, id: @sale.id
  end

  def invoice
    return unless @sale = find_and_check
    ActiveRecord::Base.transaction do
      raise ActiveRecord::Rollback unless @sale.invoice
    end
    redirect_to action: :show, id: @sale.id
  end

  def propose
    return unless @sale = find_and_check
    @sale.propose
    redirect_to action: :show, id: @sale.id
  end

  def propose_and_invoice
    return unless @sale = find_and_check
    ActiveRecord::Base.transaction do
      raise ActiveRecord::Rollback unless @sale.propose
      raise ActiveRecord::Rollback unless @sale.confirm
      # raise ActiveRecord::Rollback unless @sale.deliver
      raise ActiveRecord::Rollback unless @sale.invoice
    end
    redirect_to action: :show, id: @sale.id
  end

  def refuse
    return unless @sale = find_and_check
    @sale.refuse
    redirect_to action: :show, id: @sale.id
  end

end
