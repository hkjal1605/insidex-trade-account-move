module insidex_trade::trading_manager_actions {
    use sui::coin::{Self, Coin};
    use std::type_name::{Self, TypeName};
    use sui::event;

    use insidex_trade::config::{Config, TradingManagerCap};
    use insidex_trade::trade_account::{Self, TradeAsset, Promise};

    public struct AssetBorrowedByTradingManagerEvent has copy, drop {
        asset_id: ID,
        user: address,
        amount: u64,
        coin: TypeName
    }

    public struct AssetDepositedByTradingManager has copy, drop {
        asset_id: ID,
        user: address,
        amount: u64,
        coin: TypeName
    }

    public fun borrow_asset_for_trading<C, D>(
        trading_manager_cap: &TradingManagerCap,
        trade_asset: &mut TradeAsset<C>, 
        amount: u64, 
        user_address: address, 
        trade_config: &Config, 
        ctx: &mut TxContext
    ): (Coin<C>, Promise) {
        let asset_id = object::id(trade_asset);

        let (coin, promise) = trade_account::borrow_asset_for_trading<C, D>(
            trading_manager_cap,
            trade_asset, 
            amount, 
            user_address, 
            trade_config, 
            ctx
        );

        let asset_borrowed_event = AssetBorrowedByTradingManagerEvent {
            asset_id: asset_id,
            amount: amount,
            coin: type_name::get<C>(),
            user: user_address
        };
        event::emit<AssetBorrowedByTradingManagerEvent>(asset_borrowed_event);

        (coin, promise)
    }

    public fun deposit_new_asset_as_trading_manager<C>(
        trading_manager_cap: &TradingManagerCap,
        user_address: address, 
        coin: Coin<C>, 
        trade_config: &Config, 
        promise: Promise, 
        ctx: &mut TxContext
    ) {
        let coin_amount = coin::value(&coin);
        let asset_id = trade_account::deposit_new_asset_as_trading_manager<C>(
            trading_manager_cap,
            user_address, 
            coin, 
            trade_config, 
            promise, 
            ctx
        );

        let asset_deposited_by_trading_manager_event = AssetDepositedByTradingManager {
            asset_id: asset_id,
            amount: coin_amount,
            coin: type_name::get<C>(),
            user: user_address
        };

        event::emit<AssetDepositedByTradingManager>(asset_deposited_by_trading_manager_event);
    }

    public fun deposit_existing_asset_as_trading_manager<C>(
        trading_manager_cap: &TradingManagerCap,
        coin: Coin<C>, 
        trade_asset: &mut TradeAsset<C>, 
        user_address: address, 
        trade_config: &Config, 
        promise: Promise, 
        ctx: &mut TxContext
    ) {
        let asset_id = object::id(trade_asset);
        let coin_amount = coin::value(&coin);

        trade_account::deposit_existing_asset_as_trading_manager<C>(
            trading_manager_cap,
            coin, 
            trade_asset, 
            user_address, 
            trade_config, 
            promise, 
            ctx
        );

        let asset_deposited_by_trading_manager_event = AssetDepositedByTradingManager {
            asset_id: asset_id,
            amount: coin_amount,
            coin: type_name::get<C>(),
            user: user_address
        };

        event::emit<AssetDepositedByTradingManager>(asset_deposited_by_trading_manager_event);
    }
}