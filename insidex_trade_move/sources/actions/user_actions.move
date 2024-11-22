module insidex_trade::user_actions {
    use sui::coin::{Self, Coin};
    use std::type_name::{Self, TypeName};
    use sui::event;

    use insidex_trade::config::{Self, Config};
    use insidex_trade::trade_account::{Self, TradeAsset};

    public struct AssetDepositedEvent has copy, drop {
        asset_id: ID,
        amount: u64,
        user: address,
        coin: TypeName
    }

    public struct AssetWithdrawnEvent has copy, drop {
        asset_id: ID,
        amount: u64,
        user: address,
        coin: TypeName
    }

    public entry fun deposit_new_asset_entry<C>(coin: Coin<C>, tradeConfig: &Config, ctx: &mut TxContext) {
        let coin_amount = coin::value(&coin);

        let asset_id = trade_account::deposit_new_asset<C>(coin, tradeConfig, ctx);

        let asset_deposited_event = AssetDepositedEvent {
            asset_id: asset_id,
            amount: coin_amount,
            user: tx_context::sender(ctx),
            coin: type_name::get<C>()
        };
        event::emit<AssetDepositedEvent>(asset_deposited_event);
    }

    public entry fun deposit_existing_asset_entry<C>(coin: Coin<C>, trade_asset: &mut TradeAsset<C>, trade_config: &Config, ctx: &mut TxContext) {
        config::assert_address_is_not_trading_manager(tx_context::sender(ctx), trade_config);

        let coin_amount = coin::value(&coin);
        let asset_id = object::id(trade_asset);

        trade_account::deposit_existing_asset<C>(coin, trade_asset, trade_config, ctx);

        let asset_deposited_event = AssetDepositedEvent {
            asset_id: asset_id,
            amount: coin_amount,
            user: tx_context::sender(ctx),
            coin: type_name::get<C>()
        };
        event::emit<AssetDepositedEvent>(asset_deposited_event);
    }

    public entry fun withdraw_asset_entry<C>(trade_asset: &mut TradeAsset<C>, amount: u64, trade_config: &Config, ctx: &mut TxContext) {
        let asset_id = object::id(trade_asset);

        trade_account::withdraw_asset<C>(trade_asset, amount, trade_config, ctx);

        let asset_withdrawn_event = AssetWithdrawnEvent {
            asset_id: asset_id,
            amount: amount,
            user: tx_context::sender(ctx),
            coin: type_name::get<C>()
        };
        event::emit<AssetWithdrawnEvent>(asset_withdrawn_event);
    }
}