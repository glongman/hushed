require 'spec_helper'
require 'hushed/documents/request/shipment_order'

module Hushed
  module Documents
    module Request
      describe "ShipmentOrder" do
        include Hushed::Documents::DocumentInterfaceTestcases

        before do
          @order = OrderDouble.example
          @client = ClientDouble.new(:client_id => 'HUSHED', :business_unit => 'HUSHED', :warehouse => 'SPACE')
          @object = @shipment_order = ShipmentOrder.new(:order => @order, :client => @client)
        end

        it "should be possible to initialize a ShipmentOrder" do
          shipment_order = ShipmentOrder.new(:order => @order, :client => @client)
          assert_equal @order, shipment_order.order
        end

        it "should raise an error if an order wasn't passed in" do
          assert_raises ShipmentOrder::MissingOrderError do
            ShipmentOrder.new
          end
        end

        it "should be able to generate an XML document" do
          message = ShipmentOrder.new(:order => @order, :client => @client)
          document = Nokogiri::XML::Document.parse(message.to_xml)

          expected_namespaces = {'xmlns' => ShipmentOrder::NAMESPACE}
          assert_equal expected_namespaces, document.collect_namespaces()

          assert_equal 1, document.css('ShipOrderDocument').length

          assert_equal @client.client_id, document.css('ClientID').first.text
          assert_equal @client.business_unit, document.css('BusinessUnit').first.text

          assert_header(document.css('OrderHeader').first)
          assert_equal @order.note, document.css('Comments').first.text

          assert_shipping(document.css('ShipMode').first)

          assert_address(@order.email, @order.shipping_address, document.css('ShipTo').first)
          assert_address(@order.email, @order.billing_address, document.css('BillTo').first)

          assert_equal @order.total_price.to_s, document.css('DeclaredValue').first.text

          order_details = document.css('OrderDetails')
          assert_equal 1, order_details.length
          assert_line_item(@order.line_items.first, order_details.first)
        end

        private
        def assert_header(header)
          assert_equal "#{@order.id}", header['OrderNumber']
          assert_equal @order.created_at.utc.to_s, header['OrderDate']
          assert_equal @order.created_at.utc.to_s, header['ShipDate']
          assert_equal @order.type, header['OrderType']
        end

        def assert_shipping(shipping)
          assert_equal 'FEDEX', shipping['Carrier']
          assert_equal 'GROUND', shipping['ServiceLevel']
        end

        def assert_line_item(expected_line_item, line_item)
          assert_equal expected_line_item.id.to_s, line_item['ItemNumber']
          assert_equal "1", line_item['Line']
          assert_equal expected_line_item.quantity.to_s, line_item['QuantityOrdered']
          assert_equal expected_line_item.quantity.to_s, line_item['QuantityToShip']
          assert_equal expected_line_item.unit_of_measure, line_item['UOM']
          assert_equal expected_line_item.price, line_item['Price']
        end

        def assert_address(email, address, node)
          assert_equal address.company, node['Company']
          assert_equal address.name, node['Contact']
          assert_equal address.address1, node['Address1']
          assert_equal address.address2, node['Address2']
          assert_equal address.city, node['City']
          assert_equal address.province_code, node['State']
          assert_equal address.zip, node['PostalCode']
          assert_equal address.country_code, node['Country']
          assert_equal email, node['Email']
        end
      end
    end
  end
end