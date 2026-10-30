package house_model_pkg is
    type vertex_t is record
        x : integer range -128 to 128;
        y : integer range -128 to 160;
        z : integer range -80 to 80;
    end record;

    type vertex_array_t is array (natural range <>) of vertex_t;

    constant HOUSE_CENTER_X : integer := 0;
    constant HOUSE_CENTER_Y : integer := 25;
    constant HOUSE_CENTER_Z : integer := 0;
    constant HOUSE_VERTICES : vertex_array_t(0 to 13) := (
        (x => -100, y => -80, z =>  60),
        (x =>  100, y => -80, z =>  60),
        (x => -100, y =>   0, z =>  60),
        (x =>  100, y =>   0, z =>  60),
        (x =>    0, y => 105, z =>  60),
        (x =>  -50, y =>  52, z =>  60),
        (x =>   50, y =>  52, z =>  60),
        (x => -100, y => -80, z => -60),
        (x =>  100, y => -80, z => -60),
        (x => -100, y =>   0, z => -60),
        (x =>  100, y =>   0, z => -60),
        (x =>    0, y => 105, z => -60),
        (x =>   50, y =>  52, z => -60),
        (x =>  -50, y =>  52, z => -60)
    );
end package house_model_pkg;
