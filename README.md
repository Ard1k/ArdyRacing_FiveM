# ArdyRacing_FiveM

I wrote this script mainly to race with my friends on our local server (I hate GTA:O loading times so much), but I also tried to make it appealing for roleplay servers - to support racing communities. Thanks to the leaderboards it may be also useful tool for car devs to set up couple benchmark races to match car-car performance. Feel free to use it and further modify it.

https://www.youtube.com/watch?v=6OyVY8LlxpA

Update v1.3
- added SQL support (oxmysql)

Features:
- Make your own race templates
  - Multiple race types: Sprint/Circuit/Drift sprint/Drift circuit
  - Place checkpoints on you position or using map
- Create event for players to join
  - You can make it public and others will receive notification
  - Set registration time period
  - Enable splistream
  - Prohibit exiting car during race
- Share your race templates with other players
  - You can se template as publicly listed and other plazers can then use it to create events
  - Browse all listed templates, optionally filter them by author or race type
  - Admin can verify certain race templates and you can access them separately - to filter "trash" templates
- Leaderboards
  - Each race has its own leaderboards - global for all cars and separate leaderboard for each car model
  - During event creation is validated and displayed if the result will be eligible to rank in leaderboards (eg. slipstream off)
  - If top20 rank in global leaderboard of verified race is reached by a player, notification will be sent to other players
- Drift race modes
  - Score is awarded based on drift angle + speed and score multiplier increases for drift duration - parameters customizable in config
  - Win condition for drift sprint is the amount of points obtained through the whole race. For drift circuit best lap wins.
  - If player wants to cheat and drives away from next checkpoint the score resets
- Tools and settings
  - Players can block out of race notifications (new records, new events created, etc.)
  - Players can set drift tire physics for car - introduced in tuners update. Possible to disable in config
  - Little gimmick - enable car light flash when car horn is used
  - Drift overlay in freemode - if you just want to have some fun or train drifting
- Admin moderation
  - Custom admin login
  - Verification of race templates - to filter the best races from others for your players. Also verified race can't be deleted by owner
  - Rename race - players can't rename their race to avoid confusion for others, but admin has the option. 
  - Reset car model from leaderboards - useful when handling of a car is modified all records set by the car can be reset
- No SQL server needed
  - I wrote the script with SQL conversion in mind (server_interfacing.lua), but for now all data is stored on server serialized to KVP strings
  - Update 1.3 SQL support is now implemented for oxmysql. To keep using old kvp storage method please change in config "use_sql" to false
        