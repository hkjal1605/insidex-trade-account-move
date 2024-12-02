module insidex_trade::trade_account {
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use std::type_name::{Self, TypeName};

    use insidex_trade::config::{Self, Config, TradingManagerCap};

    const EAmountMoreThanAssetBalance: u64 = 4;
    const ETradeAssetNotBelongsToUser: u64 = 5;
    const EPromiseAndUserMismatch: u64 = 6;
    const EPromiseAndCoinTypeMismatch: u64 = 7;

    public struct TradeAsset<phantom C> has key {
        id: UID,
        user: address,
        balance: Balance<C>,
    }

    public struct Promise {
        // ensure the funds are deposited to the same user's accounts
        user: address,
        borrowed_for: TypeName
    }

    public(package) fun assert_trade_asset_belongs_to_user<C>(user: address, trade_asset: &TradeAsset<C>) {
        assert!(trade_asset.user == user, ETradeAssetNotBelongsToUser);
    }

    public(package) fun deposit_new_asset<C>(coin: Coin<C>, trade_config: &Config, ctx: &mut TxContext): ID {
        config::assert_interacting_with_most_up_to_date_package(trade_config);

        let user_address = tx_context::sender(ctx);
        let balance_to_deposit = coin::into_balance(coin);

        let trade_asset = TradeAsset {
            id: object::new(ctx),
            user: user_address,
            balance: balance_to_deposit,
        };

        let asset_id = object::id(&trade_asset);

        transfer::share_object(trade_asset);

        asset_id
    }

    #[allow(unused_mut_parameter)]
    public(package) fun deposit_existing_asset<C>(coin: Coin<C>, trade_asset: &mut TradeAsset<C>, trade_config: &Config) {
        config::assert_interacting_with_most_up_to_date_package(trade_config);

        let balance_to_deposit = coin::into_balance(coin);
        let mut_current_balance = &mut trade_asset.balance;

        balance::join(mut_current_balance, balance_to_deposit);
    }

    #[allow(lint(self_transfer))]
    public(package) fun withdraw_asset<C>(trade_asset: &mut TradeAsset<C>, amount: u64, trade_config: &Config, ctx: &mut TxContext) {
        config::assert_interacting_with_most_up_to_date_package(trade_config);
        config::assert_address_is_not_trading_manager(tx_context::sender(ctx), trade_config);
        assert_trade_asset_belongs_to_user<C>(tx_context::sender(ctx), trade_asset);

        let asset_balance = &mut trade_asset.balance;
        let asset_balance_value = balance::value(asset_balance);

        // Assert that amount is less than or equal to asset_balance_value
        assert!(amount <= asset_balance_value, EAmountMoreThanAssetBalance);

        // Split the required balance
        let required_balance = balance::split(asset_balance, amount);
        let coin_to_transfer = coin::from_balance(required_balance, ctx);

        transfer::public_transfer(coin_to_transfer, tx_context::sender(ctx));
    }

    public(package) fun borrow_asset_for_trading<C, D>(
        trading_manager_cap: &TradingManagerCap,
        trade_asset: &mut TradeAsset<C>, 
        amount: u64, 
        user_address: address, 
        trade_config: &Config, 
        ctx: &mut TxContext
    ): (Coin<C>, Promise) {
        config::assert_interacting_with_most_up_to_date_package(trade_config);
        config::assert_address_is_trading_manager(trading_manager_cap, trade_config, ctx);

        assert_trade_asset_belongs_to_user<C>(user_address, trade_asset);

        let asset_balance = &mut trade_asset.balance;
        let asset_balance_value = balance::value(asset_balance);

        // Assert that amount is less than or equal to asset_balance_value
        assert!(amount <= asset_balance_value, EAmountMoreThanAssetBalance);

        // Split the required balance
        let required_balance = balance::split(asset_balance, amount);
        let coin_to_return = coin::from_balance(required_balance, ctx);

        let promise = Promise {
            user: user_address,
            borrowed_for: type_name::get<D>()
        };

        (coin_to_return, promise)
    }

    public(package) fun deposit_new_asset_as_trading_manager<C>(
        trading_manager_cap: &TradingManagerCap,
        user_address: address, 
        coin: Coin<C>, 
        trade_config: &Config, 
        promise: Promise, 
        ctx: &mut TxContext
    ): ID {
        config::assert_interacting_with_most_up_to_date_package(trade_config);
        config::assert_address_is_trading_manager(trading_manager_cap, trade_config, ctx);

        let Promise { user, borrowed_for } = promise;
        assert!(user == user_address, EPromiseAndUserMismatch);
        assert!(borrowed_for == type_name::get<C>(), EPromiseAndCoinTypeMismatch);

        let balance_to_deposit = coin::into_balance(coin);

        let trade_asset = TradeAsset {
            id: object::new(ctx),
            user: user_address,
            balance: balance_to_deposit,
        };

        let asset_id = object::id(&trade_asset);

        // Transfer the trade_asset to the multisig account
        transfer::share_object(trade_asset);

        asset_id
    }

    public(package) fun deposit_existing_asset_as_trading_manager<C>(
        trading_manager_cap: &TradingManagerCap,
        coin: Coin<C>, 
        trade_asset: &mut TradeAsset<C>, 
        user_address: address, 
        trade_config: &Config, 
        promise: Promise, 
        ctx: &mut TxContext
    ) {
        config::assert_interacting_with_most_up_to_date_package(trade_config);
        config::assert_address_is_trading_manager(trading_manager_cap, trade_config, ctx);

        assert_trade_asset_belongs_to_user<C>(user_address, trade_asset);

        let Promise { user, borrowed_for } = promise;
        assert!(user == user_address, EPromiseAndUserMismatch);
        assert!(borrowed_for == type_name::get<C>(), EPromiseAndCoinTypeMismatch);

        deposit_existing_asset<C>(coin, trade_asset, trade_config);
    }

    public(package) fun borrow_asset_to_place_limit_order<C>(
        trading_manager_cap: &TradingManagerCap,
        trade_asset: &mut TradeAsset<C>, 
        amount: u64, 
        user_address: address, 
        trade_config: &Config, 
        ctx: &mut TxContext
    ): Coin<C> {
        config::assert_interacting_with_most_up_to_date_package(trade_config);
        config::assert_address_is_trading_manager(trading_manager_cap, trade_config, ctx);

        assert_trade_asset_belongs_to_user<C>(user_address, trade_asset);

        let asset_balance = &mut trade_asset.balance;
        let asset_balance_value = balance::value(asset_balance);

        // Assert that amount is less than or equal to asset_balance_value
        assert!(amount <= asset_balance_value, EAmountMoreThanAssetBalance);

        // Split the required balance
        let required_balance = balance::split(asset_balance, amount);
        let coin_to_return = coin::from_balance(required_balance, ctx);

        coin_to_return
    }
}