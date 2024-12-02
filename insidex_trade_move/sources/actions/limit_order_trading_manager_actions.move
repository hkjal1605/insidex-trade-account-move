module insidex_trade::limit_order_trading_manager_actions {
    use sui::coin::{Self, Coin};
    use std::type_name::{Self, TypeName};
    use sui::clock::{Clock};
    use sui::event;

    use insidex_trade::limit_orders::{Self, InsidexLimitOrder, Promise};
    use insidex_trade::config::{Self, Config, TradingManagerCap};
    use insidex_trade::trade_account::{Self, TradeAsset};

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

    public struct LimitOrderExecutedEvent has copy, drop {
        limit_order_id: ID,
        user: address,
        trade_type: u8,
        amount_base: u64,
        amount_quote: u64,
        coin_base: TypeName,
        coin_quote: TypeName,
        target_buy_price: u64,
        tp_price: u64,
        sl_price: u64,
        min_amount_to_repay: u64
    }

    public entry fun place_limit_buy_order<BaseAsset, QuoteAsset>(
        trading_manager_cap: &TradingManagerCap,
        trade_asset: &mut TradeAsset<QuoteAsset>,
        amount: u64,
        user_address: address,
        target_price_limit_buy: u64,
        slippage: u64,
        trade_config: &Config,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let coin_quote = trade_account::borrow_asset_to_place_limit_order<QuoteAsset>(
            trading_manager_cap,
            trade_asset,
            amount,
            user_address,
            trade_config,
            ctx
        );

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
            amount: amount,
            user: user_address,
            coin: type_name::get<BaseAsset>(),
            target_price: target_price_limit_buy
        };
        event::emit<LimitBuyOrderPlacedEvent>(limit_buy_order_placed_event);
    }

    public entry fun place_tpsl_order<BaseAsset, QuoteAsset>(
        trading_manager_cap: &TradingManagerCap,
        trade_asset: &mut TradeAsset<BaseAsset>,
        amount: u64,
        target_price_take_profit: u64,
        target_price_stop_loss: u64,
        slippage: u64,
        trade_config: &Config,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let coin_base = trade_account::borrow_asset_to_place_limit_order<BaseAsset>(
            trading_manager_cap,
            trade_asset,
            amount,
            tx_context::sender(ctx),
            trade_config,
            ctx
        );

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
            amount,
            user: tx_context::sender(ctx),
            coin: type_name::get<BaseAsset>(),
            tp_price: target_price_take_profit,
            sl_price: target_price_stop_loss
        };
        event::emit<LimitSellOrderPlacedEvent>(limit_sell_order_placed_event);
    }

    public entry fun update_limit_order<BaseAsset, QuoteAsset>(
        trading_manager_cap: &TradingManagerCap,
        limit_order: &mut InsidexLimitOrder<BaseAsset, QuoteAsset>,
        user_address: address,
        target_price_limit_buy: Option<u64>,
        target_price_take_profit: Option<u64>,
        target_price_stop_loss: Option<u64>,
        trade_config: &Config,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        config::assert_address_is_trading_manager(trading_manager_cap, trade_config, ctx);
        limit_orders::assert_limit_order_belongs_to_user<BaseAsset, QuoteAsset>(limit_order, user_address);
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

    public fun borrow_asset_to_execute_order<BaseAsset, QuoteAsset>(
        trading_manager_cap: &TradingManagerCap,
        limit_order: &mut InsidexLimitOrder<BaseAsset, QuoteAsset>,
        // trade_type for which trading manager needs these funds, 1 -> Limit buy 2 -> Take profit, 3 -> Stop loss
        trade_type: u8,
        trade_config: &Config,
        ctx: &mut TxContext
    ): (Coin<BaseAsset>, Coin<QuoteAsset>, Promise) {
        let (coin_base, coin_quote, promise) = limit_orders::borrow_asset_to_execute_order(
            trading_manager_cap,
            limit_order,
            trade_type,
            trade_config,
            ctx
        );

        (coin_base, coin_quote, promise)
    }

    #[allow(lint(self_transfer))]
    public fun return_asset_after_order_execution<BaseAsset, QuoteAsset>(
        trading_manager_cap: &TradingManagerCap,
        limit_order: InsidexLimitOrder<BaseAsset, QuoteAsset>,
        coin_base: Coin<BaseAsset>,
        coin_quote: Coin<QuoteAsset>,
        promise: Promise,
        base_decimals: u64,
        quote_decimals: u64,
        trade_config: &Config,
        ctx: &mut TxContext
    ) {
        let amount_base = coin::value(&coin_base);
        let amount_quote = coin::value(&coin_quote);

        let (
            mut coin_base_to_return,
            mut coin_quote_to_return,
            remaining_base_asset,
            remaining_quote_asset,
            target_buy_price,
            tp_price,
            sl_price,
            user,
            limit_order_id,
            trade_type,
            min_amount_to_repay
        ) = limit_orders::return_asset_after_order_execution(
            trading_manager_cap,
            limit_order,
            coin_base,
            coin_quote,
            promise,
            base_decimals,
            quote_decimals,
            trade_config,
            ctx
        );

        // Take out 1.2% from the coin_base and coin_quote to cover the trading fee
        let fee_value_base = amount_base * 120 / 100;
        let fee_value_quote = amount_quote * 120 / 100;

        let coin_base_fee = coin::split(&mut coin_base_to_return, fee_value_base, ctx);
        let coin_quote_fee = coin::split(&mut coin_quote_to_return, fee_value_quote, ctx);

        transfer::public_transfer(coin_base_fee, tx_context::sender(ctx));
        transfer::public_transfer(coin_quote_fee, tx_context::sender(ctx));

        transfer::public_transfer(coin_base_to_return, user);
        transfer::public_transfer(coin_quote_to_return, user);
        transfer::public_transfer(remaining_base_asset, user);
        transfer::public_transfer(remaining_quote_asset, user);

        let limit_order_executed_event = LimitOrderExecutedEvent {
            limit_order_id,
            user,
            trade_type,
            target_buy_price,
            tp_price,
            sl_price,
            amount_base,
            amount_quote,
            min_amount_to_repay,
            coin_base: type_name::get<BaseAsset>(),
            coin_quote: type_name::get<QuoteAsset>()
        };
        event::emit<LimitOrderExecutedEvent>(limit_order_executed_event);
    }
}