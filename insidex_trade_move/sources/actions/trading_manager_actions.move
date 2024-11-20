module insidex_trade::trading_manager_actions {
    use sui::coin::{Self, Coin};
    use std::type_name::{Self, TypeName};
    use sui::event;

    use insidex_trade::config::{Self, Config};
    use insidex_trade::trade_account::{Self, TradeAsset};

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

    public fun borrow_asset_for_trading<C>(trade_asset: &mut TradeAsset<C>, amount: u64, user_address: address, trade_config: &Config, ctx: &mut TxContext): Coin<C> {
        let asset_id = object::id(trade_asset);

        let coin = trade_account::borrow_asset_for_trading<C>(trade_asset, amount, trade_config, ctx);

        let asset_borrowed_event = AssetBorrowedByTradingManagerEvent {
            asset_id: asset_id,
            amount: amount,
            coin: type_name::get<C>(),
            user: user_address
        };
        event::emit<AssetBorrowedByTradingManagerEvent>(asset_borrowed_event);

        coin
    }

    public entry fun deposit_new_asset_as_trading_manager<C>(user_address: address, multisig_address: address, coin: Coin<C>, trade_config: &Config, ctx: &mut TxContext) {
        let coin_amount = coin::value(&coin);
        let asset_id = trade_account::deposit_new_asset_as_trading_manager<C>(user_address, multisig_address, coin, trade_config, ctx);

        let asset_deposited_by_trading_manager_event = AssetDepositedByTradingManager {
            asset_id: asset_id,
            amount: coin_amount,
            coin: type_name::get<C>(),
            user: user_address
        };

        event::emit<AssetDepositedByTradingManager>(asset_deposited_by_trading_manager_event);
    }

    public entry fun deposit_existing_asset_as_trading_manager<C>(coin: Coin<C>, trade_asset: &mut TradeAsset<C>, user_address: address, trade_config: &Config, ctx: &mut TxContext) {
        config::assert_address_is_trading_manager(tx_context::sender(ctx), trade_config);

        let asset_id = object::id(trade_asset);
        let coin_amount = coin::value(&coin);

        trade_account::deposit_existing_asset<C>(coin, trade_asset, trade_config);

        let asset_deposited_by_trading_manager_event = AssetDepositedByTradingManager {
            asset_id: asset_id,
            amount: coin_amount,
            coin: type_name::get<C>(),
            user: user_address
        };

        event::emit<AssetDepositedByTradingManager>(asset_deposited_by_trading_manager_event);
    }
}