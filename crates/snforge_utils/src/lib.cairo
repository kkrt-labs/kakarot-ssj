#[cfg(target: 'test')]
pub mod snforge_utils {
    use core::array::ArrayTrait;
    use core::option::OptionTrait;
    use starknet::testing::cheatcode;
    use starknet::ContractAddress;
    use snforge_std::cheatcodes::handle_cheatcode;
    use snforge_std::{Event, spy_events, EventSpy, EventSpyAssertionsTrait, EventSpyTrait};
    use snforge_std::cheatcodes::events::{Events};
    use array_utils::ArrayExtTrait;

    mod array_utils {
        #[generate_trait]
        pub impl ArrayExtImpl<T, +Copy<T>, +Drop<T>> of ArrayExtTrait<T> {
            fn includes<+PartialEq<T>>(self: @Array<T>, item: T) -> bool {
                let mut i = 0;
                let mut found = false;
                found =
                    loop {
                        if i == self.len() {
                            break false;
                        };
                        if (*self.at(i)) == item {
                            break true;
                        }
                        i += 1;
                    };
                return found;
            }
        }
    }

    /// A wrapper structure on an array of events emitted by a given contract.
    #[derive(Drop, Clone)]
    pub struct ContractEvents {
        pub events: Array<Event>
    }

    pub trait EventsFilterTrait {
        fn emitted_by(self: @Events, contract_address: ContractAddress) -> EventsFilter;
    }

    impl EventsFilterTraitImpl of EventsFilterTrait {
        fn emitted_by(self: @Events, contract_address: ContractAddress) -> EventsFilter {
            EventsFilter {
                events: self,
                contract_address: Option::Some(contract_address),
                key_filter: Option::None,
                data_filter: Option::None,
            }
        }
    }

    #[derive(Copy, Drop)]
    pub struct EventsFilter {
        events: @Events,
        contract_address: Option<ContractAddress>,
        key_filter: Option<Span<felt252>>,
        data_filter: Option<felt252>,
    }

    pub trait EventsFilterBuilderTrait {
        fn from_events(events: @Events) -> EventsFilter;
        fn with_contract_address(
            self: EventsFilter, contract_address: ContractAddress
        ) -> EventsFilter;
        fn with_keys(self: EventsFilter, keys: Span<felt252>) -> EventsFilter;
        fn with_data(self: EventsFilter, data: felt252) -> EventsFilter;
        fn build(self: @EventsFilter) -> ContractEvents;
    }

    impl EventsFilterBuilderTraitImpl of EventsFilterBuilderTrait {
        fn from_events(events: @Events) -> EventsFilter {
            EventsFilter {
                events: events,
                contract_address: Option::None,
                key_filter: Option::None,
                data_filter: Option::None,
            }
        }

        fn with_contract_address(
            mut self: EventsFilter, contract_address: ContractAddress
        ) -> EventsFilter {
            self.contract_address = Option::Some(contract_address);
            self
        }

        fn with_keys(mut self: EventsFilter, keys: Span<felt252>) -> EventsFilter {
            self.key_filter = Option::Some(keys);
            self
        }

        fn with_data(mut self: EventsFilter, data: felt252) -> EventsFilter {
            self.data_filter = Option::Some(data);
            self
        }

        fn build(self: @EventsFilter) -> ContractEvents {
            let events = (*self.events.events).span();
            let mut filtered_events = array![];
            let mut i = 0;

            while i < events.len() {
                let (from, event) = events.at(i).clone();
                let mut include = true;

                if let Option::Some(addr) = self.contract_address {
                    if from != *addr {
                        include = false;
                    }
                }

                if include && self.key_filter.is_some() {
                    if !(event.keys.span() == (*self.key_filter).unwrap()) {
                        include = false;
                    }
                }

                if include && self.data_filter.is_some() {
                    if !event.data.includes((*self.data_filter).unwrap()) {
                        include = false;
                    }
                }

                if include {
                    filtered_events.append(event.clone());
                }

                i += 1;
            };

            ContractEvents { events: filtered_events }
        }
    }

    pub trait ContractEventsTrait {
        fn assert_emitted<T, impl TEvent: starknet::Event<T>, impl TDrop: Drop<T>>(
            self: ContractEvents, event: @T
        );
        fn assert_not_emitted<T, impl TEvent: starknet::Event<T>, impl TDrop: Drop<T>>(
            self: ContractEvents, event: @T
        );
    }

    impl ContractEventsTraitImpl of ContractEventsTrait {
        fn assert_emitted<T, impl TEvent: starknet::Event<T>, impl TDrop: Drop<T>>(
            self: ContractEvents, event: @T
        ) {
            let mut expected_keys = array![];
            let mut expected_data = array![];
            event.append_keys_and_data(ref expected_keys, ref expected_data);

            let mut i = 0;
            let mut found = false;
            while i < self.events.len() {
                let event = self.events.at(i);
                if event.keys == @expected_keys && event.data == @expected_data {
                    found = true;
                    break;
                }
                i += 1;
            };

            assert(found, 'Expected event was not emitted');
        }

        fn assert_not_emitted<T, impl TEvent: starknet::Event<T>, impl TDrop: Drop<T>>(
            self: ContractEvents, event: @T
        ) {
            let mut expected_keys = array![];
            let mut expected_data = array![];
            event.append_keys_and_data(ref expected_keys, ref expected_data);

            let mut i = 0;
            while i < self.events.len() {
                let event = self.events.at(i);
                assert(
                    event.keys != @expected_keys || event.data != @expected_data,
                    'Unexpected event was emitted'
                );
                i += 1;
            }
        }
    }
}
