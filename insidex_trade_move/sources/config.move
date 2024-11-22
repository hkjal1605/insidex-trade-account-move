module insidex_trade::config {
    use sui::types;
    
    use insidex_trade::app::{AdminCap};

    const ENotLatestVersion: u64 = 0;
    const EAddressIsNotTradingManager: u64 = 1;
    const EAddressIsTradingManager: u64 = 2;
    const ETypeNotOneTimeWitness: u64 = 3;

    public struct CONFIG has drop {}

    public struct Config has key {
        id: UID,
        version: u64,
        trading_manager: address
    }


    public struct TradingManagerCap has key, store {
        id: UID,
        trading_manager: address
    }

    public fun assert_interacting_with_most_up_to_date_package(config: &Config) {
        assert!(config.version == 1, ENotLatestVersion);
    }

    public fun assert_address_is_trading_manager(trading_manager_cap: &TradingManagerCap, config: &Config, ctx: &mut TxContext) {
        assert!(trading_manager_cap.trading_manager == tx_context::sender(ctx), EAddressIsNotTradingManager);
        assert!(config.trading_manager == tx_context::sender(ctx), EAddressIsNotTradingManager);
    }

    public fun assert_address_is_not_trading_manager(user: address, config: &Config) {
        assert!(config.trading_manager != user, EAddressIsTradingManager)
    }

    public(package) fun create_config(otw: &CONFIG, ctx: &mut TxContext) {
        assert!(types::is_one_time_witness<CONFIG>(otw), ETypeNotOneTimeWitness);

        let config = Config{
            id: object::new(ctx), 
            version: 1,
            trading_manager: tx_context::sender(ctx),
        };

        transfer::share_object(config);
    }
    
    fun init(otw: CONFIG, ctx: &mut TxContext) {
        create_config(&otw, ctx);
    }
    
    public fun assign_trading_manager(_admin_cap: &AdminCap, config: &mut Config, trading_manager_address: address, ctx: &mut TxContext) {
        assert_interacting_with_most_up_to_date_package(config);

        config.trading_manager = trading_manager_address;
        
        let trading_manager_cap = TradingManagerCap{
            id: object::new(ctx),
            trading_manager: trading_manager_address,
        };

        transfer::transfer(trading_manager_cap, trading_manager_address);
    }
}