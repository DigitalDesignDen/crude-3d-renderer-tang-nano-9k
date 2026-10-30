package control_reg_pkg is
    type register_t is record
        FOCAL_LENGTH : positive range 1 to 255;
        DEPTH_SCALE  : natural range 0 to 255;
    end record;
end package;

package body control_reg_pkg is

end package body;