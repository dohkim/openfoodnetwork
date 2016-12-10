require 'spec_helper'

describe ProxyOrder, type: :model do
  describe "cancel" do
    let(:order_cycle) { create(:simple_order_cycle) }
    let(:standing_order) { create(:standing_order, orders: [order]) }
    let(:proxy_order) { standing_order.proxy_orders.first }

    context "when the order cycle for the order is not yet closed" do
      before { order_cycle.update_attributes(orders_open_at: 1.day.ago, orders_close_at: 3.days.from_now) }

      context "and the order has already been completed" do
        let(:order) { create(:completed_order_with_totals, order_cycle: order_cycle) }

        it "returns true and sets canceled_at to the current time, and cancels the order" do
          expect(proxy_order.cancel).to be true
          expect(proxy_order.reload.canceled_at).to be_within(5.seconds).of Time.now
          expect(order.reload.state).to eq 'canceled'
        end
      end

      context "and the order has not already been completed" do
        let(:order) { create(:order, order_cycle: order_cycle) }

        it "returns true and sets canceled_at to the current time" do
          expect(proxy_order.cancel).to be true
          expect(proxy_order.reload.canceled_at).to be_within(5.seconds).of Time.now
          expect(order.reload.state).to eq 'cart'
        end
      end
    end

    context "when the order cycle for the order is already closed" do
      let(:order) { create(:order, order_cycle: order_cycle) }

      before { order_cycle.update_attributes(orders_open_at: 3.days.ago, orders_close_at: 1.minute.ago) }

      it "returns false and does nothing" do
        expect(proxy_order.cancel).to be false
        expect(proxy_order.reload.canceled_at).to be nil
        expect(order.reload.state).to eq 'cart'
      end
    end

    context "when the order cycle for the order does not exist" do
      let(:order) { create(:order) }

      it "returns false and does nothing" do
        expect(proxy_order.cancel).to be false
        expect(proxy_order.reload.canceled_at).to be nil
        expect(order.reload.state).to eq 'cart'
      end
    end
  end

  describe "resume" do
    let(:order_cycle) { create(:simple_order_cycle) }
    let!(:payment_method) { create(:payment_method) }
    let(:order) { create(:order_with_totals, shipping_method: create(:shipping_method), order_cycle: order_cycle) }
    let(:standing_order) { create(:standing_order, orders: [order]) }
    let(:proxy_order) { standing_order.proxy_orders.first }

    before do
      # Processing order to completion
      while !order.completed? do break unless order.next! end
      proxy_order.update_attribute(:canceled_at, Time.zone.now)
    end

    context "when the order cycle for the order is not yet closed" do
      before { order_cycle.update_attributes(orders_open_at: 1.day.ago, orders_close_at: 3.days.from_now) }

      context "and the order has already been cancelled" do
        before { order.cancel }

        it "returns true, clears canceled_at and resumes the order" do
          expect(proxy_order.resume).to be true
          expect(proxy_order.reload.canceled_at).to be nil
          expect(order.reload.state).to eq 'resumed'
        end
      end

      context "and the order has not been cancelled" do
        it "returns true and clears canceled_at" do
          expect(proxy_order.resume).to be true
          expect(proxy_order.reload.canceled_at).to be nil
          expect(order.reload.state).to eq 'complete'
        end
      end
    end

    context "when the order cycle for the order is already closed" do
      before { order_cycle.update_attributes(orders_open_at: 3.days.ago, orders_close_at: 1.minute.ago) }

      context "and the order has been cancelled" do
        before { order.cancel }

        it "returns false and does nothing" do
          expect(proxy_order.resume).to eq false
          expect(proxy_order.reload.canceled_at).to be_within(5.seconds).of Time.now
          expect(order.reload.state).to eq 'canceled'
        end
      end

      context "and the order has not been cancelled" do
        it "returns false and does nothing" do
          expect(proxy_order.resume).to eq false
          expect(proxy_order.reload.canceled_at).to be_within(5.seconds).of Time.now
          expect(order.reload.state).to eq 'complete'
        end
      end
    end
  end
end