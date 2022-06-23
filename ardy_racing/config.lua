Config = {
    menu_open_key = 56,
    enable_teleport_to_race_start = true,
    enable_drift_tire_manipultion = true,
    enable_car_specific_leaderboard_notif = false,
    use_sql = true,
    migrate_nonsql_data = false, --!!! When true migrates data from old kvp storage to SQL. To migrate, set to true, ensure resource and then disable. Otherwise migration will be run always on startup and new data could be overwritten.

    drift_angle_min = 8,
    drift_angle_max = 35,
    drift_end_after_ms = 1000,
    drift_min_speed = 6,
    drift_effect_mult = 30.0,
    drift_effect_speedfactor = 0.5,
    drift_min_duration = 500,
    drift_speed_cap = 20.0,
    drift_multipler_cap = 5.0,
    drift_overturn_angle = 90,
    drift_max_reverse_dist = 10,

    blip_color = 5,
    blip_passed_color = 2,
    race_start_freezetime = 5000, --ms
    race_checkpoint_type = 2,
    race_checkpoint_finish_type = 4,
    race_checkpoint_nextlap_type = 3,
    checkpoint_radius = 20.0,
    checkpoint_height = 15.0,
    checkpoint_z_offset = -13.0,
    start_radius = 40.0,

    hud_left_pos_x = 0.05,
    hud_left_pos_y = 0.05,

    hud_right_pos_x = 0.95,
    hud_right_pos_y = 0.05,

    debug_x = 0.4,
    debug_y = 0.5
}