module insidex_trade::limit_order_user_actions {
    use sui::coin::{Self, Coin};
    use std::type_name::{Self, TypeName};
    use sui::clock::{Clock};
    use sui::event;

    use insidex_trade::limit_orders::{Self, InsidexLimitOrder};
    use insidex_trade::config::{Config};

    public struct LimitBuyOrderPlacedEvent has copy, drop {
        limit_order_id: ID,
        user: address,
        amount: u64,
        target_price: u64,
        coin: TypeName
    }

    public struct LimitSellOrderPlacedEvent has copy, drop {
        limit_order_id: ID,
        user: address,
        amount: u64,
        tp_price: u64,
        sl_price: u64,
        coin: TypeName
    }

    public struct LimitOrderUpdatedEvent has copy, drop {
        limit_order_id: ID,
        user: address,
        target_price_limit_buy: u64,
        target_price_take_profit: u64,
        target_price_stop_loss: u64,
        coin: TypeName
    }

    public struct LimitOrderCancelledEvent has copy, drop {
        limit_order_id: ID,
        user: address,
        coin: TypeName
    }

    public entry fun place_limit_buy_order<BaseAsset, QuoteAsset>(
        coin_quote: Coin<QuoteAsset>,
        target_price_limit_buy: u64,
        slippage: u64,
        trade_config: &Config,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let coin_quote_amount = coin::value(&coin_quote);

        let coin_base = coin::zero<BaseAsset>(ctx);

        let limit_order_id = limit_orders::place_limit_order(
            coin_base,
            coin_quote,
            option::some<u64>(target_price_limit_buy),
            option::none<u64>(),
            option::none<u64>(),
            slippage,
            trade_config,
            clock,
            ctx
        );

        let limit_buy_order_placed_event = LimitBuyOrderPlacedEvent {
            limit_order_id,
            amount: coin_quote_amount,
            user: tx_context::sender(ctx),
            coin: type_name::get<BaseAsset>(),
            target_price: target_price_limit_buy
        };
        event::emit<LimitBuyOrderPlacedEvent>(limit_buy_order_placed_event);
    }

    public entry fun place_tpsl_order<BaseAsset, QuoteAsset>(
        coin_base: Coin<BaseAsset>,
        target_price_take_profit: u64,
        target_price_stop_loss: u64,
        slippage: u64,
        trade_config: &Config,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let coin_base_amount = coin::value(&coin_base);

        let coin_quote = coin::zero<QuoteAsset>(ctx);

        let limit_order_id = limit_orders::place_limit_order(
            coin_base,
            coin_quote,
            option::none<u64>(),
            option::some<u64>(target_price_take_profit),
            option::some<u64>(target_price_stop_loss),
            slippage,
            trade_config,
            clock,
            ctx
        );

        let limit_sell_order_placed_event = LimitSellOrderPlacedEvent {
            limit_order_id,
            amount: coin_base_amount,
            user: tx_context::sender(ctx),
            coin: type_name::get<BaseAsset>(),
            tp_price: target_price_take_profit,
            sl_price: target_price_stop_loss
        };
        event::emit<LimitSellOrderPlacedEvent>(limit_sell_order_placed_event);
    }

    public entry fun update_limit_order<BaseAsset, QuoteAsset>(
        limit_order: &mut InsidexLimitOrder<BaseAsset, QuoteAsset>,
        target_price_limit_buy: Option<u64>,
        target_price_take_profit: Option<u64>,
        target_price_stop_loss: Option<u64>,
        trade_config: &Config,
        clock: &Clock,
        ctx: &TxContext
    ) {

        //TODO allow to update slippage
        // Slippage cannot be less than 0.1%
        
        limit_orders::assert_limit_order_belongs_to_user<BaseAsset, QuoteAsset>(limit_order, tx_context::sender(ctx));
        let limit_order_id = object::id(limit_order);

        let (
            target_price_limit_buy_updated, 
            target_price_take_profit_updated, 
            target_price_stop_loss_updated
        ) = limit_orders::update_limit_order(
            limit_order,
            target_price_limit_buy,
            target_price_take_profit,
            target_price_stop_loss,
            trade_config,
            clock
        );

        let limit_order_updated_event = LimitOrderUpdatedEvent {
            limit_order_id,
            user: tx_context::sender(ctx),
            coin: type_name::get<BaseAsset>(),
            target_price_limit_buy: target_price_limit_buy_updated,
            target_price_take_profit: target_price_take_profit_updated,
            target_price_stop_loss: target_price_stop_loss_updated
        };
        event::emit<LimitOrderUpdatedEvent>(limit_order_updated_event);
    }

    public entry fun cancel_limit_order<BaseAsset, QuoteAsset>(
        limit_order: InsidexLimitOrder<BaseAsset, QuoteAsset>,
        trade_config: &Config,
        ctx: &mut TxContext
    ) {
        limit_orders::assert_limit_order_belongs_to_user<BaseAsset, QuoteAsset>(&limit_order, tx_context::sender(ctx));
        let limit_order_id = object::id(&limit_order);
        
        let (coin_base, coin_quote) = limit_orders::cancel_limit_order(limit_order, trade_config, ctx);

        transfer::public_transfer(coin_base, tx_context::sender(ctx));
        transfer::public_transfer(coin_quote, tx_context::sender(ctx));

        let limit_order_cancelled_event = LimitOrderCancelledEvent {
            limit_order_id,
            user: tx_context::sender(ctx),
            coin: type_name::get<BaseAsset>()
        };
        event::emit<LimitOrderCancelledEvent>(limit_order_cancelled_event);
    }
}