module insidex_trade::limit_orders {
    use std::type_name;
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use insidex_trade::config::{Self, Config, TradingManagerCap};
    use insidex_trade::safe_math;

    const ELimitOrderNotBelongsToUser: u64 = 1;
    const EInvalidPricesForCreatingLimitOrder: u64 = 2;
    const ELimitOrderUserAndPromiseMismatch: u64 = 3;
    const ELimitOrderIdAndPromiseMismatch: u64 = 4;
    const ELimitBuyPriceNotExists: u64 = 5;
    const ETakeProfitPriceNotExists: u64 = 6;
    const EStopLossPriceNotExists: u64 = 7;
    const ELimitBuyOutputNotEnough: u64 = 8;
    const ETakeProfitOutputNotEnough: u64 = 9;
    const EStopLossOutputNotEnough: u64 = 10;

    const SlippageScaling: u64 = 10000;
    const PriceScaling: u64 = 1000000000;

    // Base Asset -> Meme coin to buy or sell at limit price, Quote Asset -> Sui or USDC only
    public struct InsidexLimitOrder<phantom BaseAsset, phantom QuoteAsset> has key {
        id: UID,
        user: address,
        // Slippage represented as value * 100 (slippage of 0.5% is 50, slippage of 5% is 500, etc.)
        slippage: u64,
        // balance of Base Asset. 0 if order is of type limit buy, non-zero if order is of type limit-sell/take profit/stop loss
        balance_base: Balance<BaseAsset>,
        // Balance of Quote Asset. 0 if order is of type limit sell/take profit/stop loss, non-zero if order is of type limit buy
        balance_quote: Balance<QuoteAsset>,
        // types of the order can be limit buy, take profit, stop loss. each of these types can have a (optional) target price
        // Whichever price hits first, that order will be executed. This helps in using the same object to handle all type of oders
        // Target price = actual price per token of Base asset * total supply of base asset
        target_price_limit_buy: Option<u64>,
        target_price_take_profit: Option<u64>,
        target_price_stop_loss: Option<u64>,
        // created at timestamp
        created_at: u64,
        // updated at timestamp
        updated_at: u64,
    }

    public struct Promise {
        // ensure the funds are deposited to the same user's accounts
        user: address,
        limit_order_id: ID,
        // trade_type for which trading manager needs these funds, 1 -> Limit buy, 2 -> Take profit, 3 -> Stop loss
        trade_type: u8,
        min_amount_to_repay: u64,
    }

    public(package) fun assert_limit_order_belongs_to_user<BaseAsset, QuoteAsset>(
        limit_order: &InsidexLimitOrder<BaseAsset, QuoteAsset>,
        user: address
    ) {
        assert!(limit_order.user == user, ELimitOrderNotBelongsToUser);
    }

    public(package) fun place_limit_order<BaseAsset, QuoteAsset>(
        coin_base: Coin<BaseAsset>,
        coin_quote: Coin<QuoteAsset>,
        target_price_limit_buy: Option<u64>,
        target_price_take_profit: Option<u64>,
        target_price_stop_loss: Option<u64>,
        slippage: u64,
        trade_config: &Config,
        clock: &Clock,
        ctx: &mut TxContext
    ): ID {
        config::assert_interacting_with_most_up_to_date_package(trade_config);
        config::assert_quote_asset_is_allowed_for_limit_order(trade_config, type_name::get<QuoteAsset>());

        let target_price_limit_buy_value = option::get_with_default(&target_price_limit_buy, 0);
        let target_price_take_profit_value = option::get_with_default(&target_price_take_profit, 0);
        let target_price_stop_loss_value = option::get_with_default(&target_price_stop_loss, 0);

        // Check that if limi_buy not exists, tp or sl should exists and vice-versa
        // Also a check that prices cannot be 0
        if (target_price_take_profit_value == 0 && target_price_stop_loss_value == 0) {
            assert!(target_price_limit_buy_value != 0, EInvalidPricesForCreatingLimitOrder);
        };

        if (target_price_limit_buy_value == 0) {
            assert!(target_price_take_profit_value != 0 || target_price_stop_loss_value != 0, EInvalidPricesForCreatingLimitOrder);
        };

        let limit_order = InsidexLimitOrder<BaseAsset, QuoteAsset> {
            id: object::new(ctx),
            user: tx_context::sender(ctx),
            slippage,
            balance_base: coin::into_balance(coin_base),
            balance_quote: coin::into_balance(coin_quote),
            target_price_limit_buy,
            target_price_take_profit,
            target_price_stop_loss,
            created_at: clock::timestamp_ms(clock),
            updated_at: clock::timestamp_ms(clock),
        };

        let limit_order_id = object::id(&limit_order);
        transfer::share_object(limit_order);

        limit_order_id
    }

    public(package) fun update_limit_order<BaseAsset, QuoteAsset>(
        limit_order: &mut InsidexLimitOrder<BaseAsset, QuoteAsset>,
        target_price_limit_buy: Option<u64>,
        target_price_take_profit: Option<u64>,
        target_price_stop_loss: Option<u64>,
        trade_config: &Config,
        clock: &Clock
    ): (u64, u64, u64) {
        config::assert_interacting_with_most_up_to_date_package(trade_config);

        if (option::is_some(&target_price_limit_buy)) {
            limit_order.target_price_limit_buy = target_price_limit_buy;
        };

        if (option::is_some(&target_price_take_profit)) {
            limit_order.target_price_take_profit = target_price_take_profit;
        };

        if (option::is_some(&target_price_stop_loss)) {
            limit_order.target_price_stop_loss = target_price_stop_loss;
        };

        limit_order.updated_at = clock::timestamp_ms(clock);

        (
            option::get_with_default(&limit_order.target_price_limit_buy, 0),
            option::get_with_default(&limit_order.target_price_take_profit, 0),
            option::get_with_default(&limit_order.target_price_stop_loss, 0),
        )
    }

    public(package) fun cancel_limit_order<BaseAsset, QuoteAsset>(
        limit_order: InsidexLimitOrder<BaseAsset, QuoteAsset>,
        trade_config: &Config,
        ctx: &mut TxContext
    ): (Coin<BaseAsset>, Coin<QuoteAsset>) {
        config::assert_interacting_with_most_up_to_date_package(trade_config);
        assert_limit_order_belongs_to_user<BaseAsset, QuoteAsset>(&limit_order, tx_context::sender(ctx));

        let InsidexLimitOrder {
            id,
            user: _user,
            slippage: _slippage,
            balance_base,
            balance_quote,
            target_price_limit_buy: _target_price_limit_buy,
            target_price_take_profit: _target_price_take_profit,
            target_price_stop_loss: _target_price_stop_loss,
            created_at: _created_at,
            updated_at: _updated_at,
        } = limit_order;

        let coin_base = coin::from_balance(balance_base, ctx);
        let coin_quote = coin::from_balance(balance_quote, ctx);

        // Delete the object
        id.delete();

        (coin_base, coin_quote)
    }

    public(package) fun borrow_asset_to_execute_order<BaseAsset, QuoteAsset>(
        trading_manager_cap: &TradingManagerCap,
        limit_order: &mut InsidexLimitOrder<BaseAsset, QuoteAsset>,
        // trade_type for which trading manager needs these funds, 1 -> Limit buy 2 -> Take profit, 3 -> Stop loss
        trade_type: u8,
        trade_config: &Config,
        ctx: &mut TxContext
    ): (Coin<BaseAsset>, Coin<QuoteAsset>, Promise) {
        config::assert_interacting_with_most_up_to_date_package(trade_config);
        config::assert_address_is_trading_manager(trading_manager_cap, trade_config, ctx);

        let balance_base = &mut limit_order.balance_base;
        let balance_base_value = balance::value(balance_base);
        let coin_base = coin::take(balance_base, balance_base_value, ctx);

        let balance_quote = &mut limit_order.balance_quote;
        let balance_quote_value = balance::value(balance_quote);
        let coin_quote = coin::take(balance_quote, balance_quote_value, ctx);

        let slippage = limit_order.slippage;

        let mut min_amount_to_repay: u64 = 0;

        // Calculate the min amount that the trading manager should repay based on slippage and price
        // If the trade was of type limit buy
        if (trade_type == 1) {
            // min amount to repay = (balance_quote_value * (1 - slippage)) / target_price_limit_buy
            let target_price_limit_buy = &mut limit_order.target_price_limit_buy;
            let target_price_limit_buy_exists = option::is_some(target_price_limit_buy);
            assert!(target_price_limit_buy_exists == true, ELimitBuyPriceNotExists);

            let limit_price_value = option::extract(target_price_limit_buy);
            min_amount_to_repay = safe_math::safe_mul_div_u64(balance_quote_value, PriceScaling * (SlippageScaling - slippage), SlippageScaling * limit_price_value)
        };

        // If the trade was of type take profit
        if (trade_type == 2) {
            // min amount to repay = (balance_base_value * (1 - slippage)) * target_price_take_profit
            let target_price_take_profit = &mut limit_order.target_price_take_profit;
            let target_price_take_profit_exists = option::is_some(target_price_take_profit);
            assert!(target_price_take_profit_exists == true, ETakeProfitPriceNotExists);

            let limit_price_value = option::extract(target_price_take_profit);
            min_amount_to_repay = safe_math::safe_mul_div_u64(balance_base_value, limit_price_value * (10000 - slippage), 10000 * PriceScaling);
        };

        // If the trade was of type stop loss
        if (trade_type == 3) {
            // min amount to repay = (balance_base_value * (1 - slippage)) * target_price_stop_loss
            let target_price_stop_loss = &mut limit_order.target_price_stop_loss;
            let target_price_stop_loss_exists = option::is_some(target_price_stop_loss);
            assert!(target_price_stop_loss_exists == true, EStopLossPriceNotExists);

            let limit_price_value = option::extract(target_price_stop_loss);
            min_amount_to_repay = safe_math::safe_mul_div_u64(balance_base_value, limit_price_value * (10000 - slippage), 10000 * PriceScaling);
        };

        let promise = Promise {
            user: limit_order.user,
            limit_order_id: object::id(limit_order),
            trade_type,
            min_amount_to_repay
        };

        (coin_base, coin_quote, promise)
    }

    public(package) fun return_asset_after_order_execution<BaseAsset, QuoteAsset>(
        trading_manager_cap: &TradingManagerCap,
        limit_order: InsidexLimitOrder<BaseAsset, QuoteAsset>,
        coin_base: Coin<BaseAsset>,
        coin_quote: Coin<QuoteAsset>,
        promise: Promise,
        base_decimals: u64,
        quote_decimals: u64,
        trade_config: &Config,
        ctx: &mut TxContext
    ): (Coin<BaseAsset>, Coin<QuoteAsset>, Coin<BaseAsset>, Coin<QuoteAsset>, u64, u64, u64, address, ID, u8, u64) {
        config::assert_interacting_with_most_up_to_date_package(trade_config);
        config::assert_address_is_trading_manager(trading_manager_cap, trade_config, ctx);

        let Promise {
            user,
            limit_order_id,
            trade_type,
            min_amount_to_repay
        } = promise;

        assert!(limit_order.user == user, ELimitOrderUserAndPromiseMismatch);
        assert!(object::id(&limit_order) == limit_order_id, ELimitOrderIdAndPromiseMismatch);

        let coin_base_value = coin::value(&coin_base);
        let coin_quote_value = coin::value(&coin_quote);

        let scaled_coin_base_value = safe_math::safe_mul_div_u64(coin_base_value, quote_decimals, base_decimals);
        let scaled_coin_quote_value = safe_math::safe_mul_div_u64(coin_quote_value, base_decimals, quote_decimals);

        if (trade_type == 1) {
            assert!(scaled_coin_base_value >= min_amount_to_repay, ELimitBuyOutputNotEnough);
        };

        if (trade_type == 2) {
            assert!(scaled_coin_quote_value >= min_amount_to_repay, ETakeProfitOutputNotEnough);
        };

        if (trade_type == 3) {
            assert!(scaled_coin_quote_value >= min_amount_to_repay, EStopLossOutputNotEnough);
        };

        let InsidexLimitOrder {
            id,
            user: _user,
            slippage: _slippage,
            balance_base,
            balance_quote,
            target_price_limit_buy,
            target_price_take_profit,
            target_price_stop_loss,
            created_at: _created_at,
            updated_at: _updated_at,
        } = limit_order;

        let remaining_base_asset = coin::from_balance(balance_base, ctx);
        let remaining_quote_asset = coin::from_balance(balance_quote, ctx);

        // Delete the limit order object
        id.delete();

        (
            coin_base,
            coin_quote,
            remaining_base_asset,
            remaining_quote_asset,
            option::get_with_default(&target_price_limit_buy, 0), 
            option::get_with_default(&target_price_take_profit, 0), 
            option::get_with_default(&target_price_stop_loss, 0),
            user,
            limit_order_id,
            trade_type,
            min_amount_to_repay
        )
    }
}