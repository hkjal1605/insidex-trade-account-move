module insidex_trade::config {
    use sui::address;
    use sui::types;
    use sui::hash;
    
    use insidex_trade::app::{AdminCap};

    public struct CONFIG has drop {}

    public struct Config has key {
        id: UID,
        version: u64,
        insidex_pk: vector<u8>
    }

    public fun insidex_pk(config: &Config): vector<u8> {
        config.insidex_pk
    }

    public fun assert_interacting_with_most_up_to_date_package(config: &Config) {
        assert!(config.version == 1, 0);
    }

    public fun assert_public_key_corresponds_to_tx_sender(pk: &vector<u8>, user_address: address) {
        assert!(user_address == address::from_bytes(hash::blake2b256(pk)), 2);
    }

    public(package) fun create_config(otw: &CONFIG, ctx: &mut TxContext) {
        assert!(types::is_one_time_witness<CONFIG>(otw), 1);

        let config = Config{
            id: object::new(ctx), 
            version: 1, 
            insidex_pk: x"0054ddafa58454c82c36bf39bb3a14568f09cc04a4fb069cc7f73b47c92bd8ff74",
        };

        transfer::share_object(config);
    }
    
    public(package) fun current_version() : u64 {
        1
    }
    
    public fun derive_multisig_address(config: &Config, user_pk: vector<u8>): address {
        assert_interacting_with_most_up_to_date_package(config);
        let mut multisig_vec = b"";

        0x1::vector::push_back<u8>(&mut multisig_vec, 3);
        0x1::vector::append<u8>(&mut multisig_vec, x"0100");
        0x1::vector::append<u8>(&mut multisig_vec, config.insidex_pk);
        0x1::vector::push_back<u8>(&mut multisig_vec, 1);
        0x1::vector::append<u8>(&mut multisig_vec, user_pk);
        0x1::vector::push_back<u8>(&mut multisig_vec, 1);

        0x2::address::from_bytes(0x2::hash::blake2b256(&multisig_vec))
    }
    
    fun init(otw: CONFIG, ctx: &mut TxContext) {
        create_config(&otw, ctx);
    }
    
    public fun update_insidex_pk(_admin_cap: &AdminCap, config: &mut Config, updated_pk: vector<u8>) {
        assert_interacting_with_most_up_to_date_package(config);
        config.insidex_pk = updated_pk;
    }
}