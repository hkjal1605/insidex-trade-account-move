module insidex_trade::user_actions {
    use sui::coin::{Self, Coin};
    use std::type_name::{Self, TypeName};
    use sui::event;

    use insidex_trade::config::{Config};
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

    public entry fun deposit_new_asset_entry<C>(user_pk: vector<u8>, coin: Coin<C>, tradeConfig: &Config, ctx: &mut TxContext) {
        let coin_amount = coin::value(&coin);

        let asset_id = trade_account::deposit_new_asset<C>(user_pk, coin, tradeConfig, ctx);

        let asset_deposited_event = AssetDepositedEvent {
            asset_id: asset_id,
            amount: coin_amount,
            user: tx_context::sender(ctx),
            coin: type_name::get<C>()
        };
        event::emit<AssetDepositedEvent>(asset_deposited_event);
    }

    public entry fun deposit_existing_asset_entry<C>(coin: Coin<C>, trade_asset: &mut TradeAsset<C>, ctx: &mut TxContext) {
        let coin_amount = coin::value(&coin);
        let asset_id = object::id(trade_asset);

        trade_account::deposit_existing_asset<C>(coin, trade_asset, ctx);

        let asset_deposited_event = AssetDepositedEvent {
            asset_id: asset_id,
            amount: coin_amount,
            user: tx_context::sender(ctx),
            coin: type_name::get<C>()
        };
        event::emit<AssetDepositedEvent>(asset_deposited_event);
    }

    public entry fun withdraw_all_assets_entry<C>(trade_asset: &mut TradeAsset<C>, ctx: &mut TxContext) {
        let asset_id = object::id(trade_asset);

        let amount = trade_account::withdraw_all_asset<C>(trade_asset, ctx);

        let asset_withdrawn_event = AssetWithdrawnEvent {
            asset_id: asset_id,
            amount: amount,
            user: tx_context::sender(ctx),
            coin: type_name::get<C>()
        };
        event::emit<AssetWithdrawnEvent>(asset_withdrawn_event);
    }
}