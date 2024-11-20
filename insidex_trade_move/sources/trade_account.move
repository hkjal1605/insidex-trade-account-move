module insidex_trade::trade_account {
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};

    use insidex_trade::config::{Self, Config};

    const EAmountMoreThanAssetBalance: u64 = 1;

    public struct TradeAsset<phantom C> has key {
        id: UID,
        user: address,
        balance: Balance<C>,
    }

    public fun deposit_new_asset<C>(multisig_address: address, coin: Coin<C>, tradeConfig: &Config, ctx: &mut TxContext): ID {
        let user_address = tx_context::sender(ctx);
        let balance_to_deposit = coin::into_balance(coin);

        let trade_asset = TradeAsset {
            id: object::new(ctx),
            user: user_address,
            balance: balance_to_deposit,
        };

        let asset_id = object::id(&trade_asset);

        // Transfer the trade_asset to the multisig account
        transfer::transfer(trade_asset, multisig_address);

        asset_id
    }

    #[allow(unused_variable)]
    public fun deposit_existing_asset<C>(coin: Coin<C>, trade_asset: &mut TradeAsset<C>, ctx: &mut TxContext) {
        let balance_to_deposit = coin::into_balance(coin);
        
        let mut_current_balance = &mut trade_asset.balance;

        balance::join(mut_current_balance, balance_to_deposit);
    }

    #[allow(lint(self_transfer))]
    public fun withdraw_all_asset<C>(trade_asset: &mut TradeAsset<C>, ctx: &mut TxContext): u64 {
        let TradeAsset {
            id: _id,
            user: _user,
            balance: current_balance
        } = trade_asset;

        let balance_to_transfer = balance::withdraw_all(current_balance);
        let coin_to_transfer = coin::from_balance(balance_to_transfer, ctx);

        let coin_value = coin::value(&coin_to_transfer);

        transfer::public_transfer(coin_to_transfer, tx_context::sender(ctx));

        coin_value
    }

    public fun borrow_asset_for_trading<C>(trade_asset: &mut TradeAsset<C>, amount: u64, ctx: &mut TxContext): Coin<C> {
        let asset_balance = &mut trade_asset.balance;
        let asset_balance_value = balance::value(asset_balance);

        // Assert that amount is less than or equal to asset_balance_value
        assert!(amount <= asset_balance_value, EAmountMoreThanAssetBalance);

        // Split the required balance
        let required_balance = balance::split(asset_balance, amount);
        let coin_to_return = coin::from_balance(required_balance, ctx);

        coin_to_return
    }

    public fun deposit_new_asset_as_trading_manager<C>(user_address: address, multisig_address: address, coin: Coin<C>, tradeConfig: &Config, ctx: &mut TxContext): ID {
        let balance_to_deposit = coin::into_balance(coin);

        let trade_asset = TradeAsset {
            id: object::new(ctx),
            user: user_address,
            balance: balance_to_deposit,
        };

        let asset_id = object::id(&trade_asset);

        // Transfer the trade_asset to the multisig account
        transfer::transfer(trade_asset, multisig_address);

        asset_id
    }
}