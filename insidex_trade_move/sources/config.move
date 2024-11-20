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

    public fun trading_manager_address(config: &Config): address {
        config.trading_manager
    }

    public fun assert_interacting_with_most_up_to_date_package(config: &Config) {
        assert!(config.version == 1, ENotLatestVersion);
    }

    public fun assert_address_is_trading_manager(user: address, config: &Config) {
        assert!(config.trading_manager == user, EAddressIsNotTradingManager)
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
    
    public fun update_trading_manager_address(_admin_cap: &AdminCap, config: &mut Config, trading_manager_address: address) {
        assert_interacting_with_most_up_to_date_package(config);
        config.trading_manager = trading_manager_address;
    }

    // public fun derive_multisig_address(config: &Config, user_pk: vector<u8>): address {
    //     assert_interacting_with_most_up_to_date_package(config);
    //     let mut multisig_vec = b"";

    //     0x1::vector::push_back<u8>(&mut multisig_vec, 3);
    //     0x1::vector::append<u8>(&mut multisig_vec, x"0100");
    //     0x1::vector::append<u8>(&mut multisig_vec, config.insidex_pk);
    //     0x1::vector::push_back<u8>(&mut multisig_vec, 1);
    //     0x1::vector::append<u8>(&mut multisig_vec, user_pk);
    //     0x1::vector::push_back<u8>(&mut multisig_vec, 1);

    //     0x2::address::from_bytes(0x2::hash::blake2b256(&multisig_vec))
    // }
}