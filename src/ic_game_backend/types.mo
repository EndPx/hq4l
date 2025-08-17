import Time "mo:base/Time";

module {
  public type RoleId = Nat;
  public type CurrentRoleId = Nat;
  public type SkinId = Nat;
  public type InventoryId = Nat;
  public type QuestId = Nat;

  // =============================
  // ROLES
  // =============================
  public type Role = {
    id : RoleId;
    name : Text;
    badge : Text;
  };

  public type CurrentRole = {
    id : CurrentRoleId;
    role_id : RoleId;
    var level : Nat;
    var exp : Nat;
    var is_active : Bool;
  };

  public type RoleProfile = {
    id : CurrentRoleId;
    name : Text;
    badge : Text;
    level : Nat;
    exp : Nat;
    is_active : Bool;
  };

  // =============================
  // USER
  // =============================
  public type User = {
    owner_principal : Principal;
    username : Text;
    var coin : Nat;
    var stamina : Nat;
    var last_action_timestamp : Time.Time;
  };

  public type DebugUser = {
    owner_principal : Principal;
    username : Text;
    coin : Nat;
    stamina : Nat;
    last_action_timestamp : Time.Time;
  };

  // =============================
  // SHOP & INVENTORY
  // =============================
  public type Skin = {
    id : SkinId;
    name : Text;
    description : Text;
    rarity : Text;
    image_url : Text;
    is_limited : Bool;
    price : Nat;
  };

  public type InventoryItem = {
    id : InventoryId;
    skin_id : SkinId;
    is_active : Bool;
    acquired_at : Time.Time;
  };

  // =============================
  // QUEST
  // =============================
  public type Quest = {
    id : QuestId;
    title : Text;
    exp_reward : Nat;
    coin_reward : Nat;
    stamina_cost : Nat;
    is_active : Bool;
  };

  // =============================
  // PROFILE
  // =============================
  public type UserProfile = {
    username : Text;
    coin : Nat;
    stamina : Nat;
    roles : [RoleProfile];
    skins : [InventoryItem];
    quests : [Quest];
  };

  // =============================
  // ERRORS
  // =============================
  public type RegistrationError = {
    #UsernameTaken;
    #AlreadyRegistered;
  };

  public type UserError = {
    #UserNotFound;
    #RoleNotFound;
  };

  public type ShopError = {
    #UserNotFound;
    #SkinNotFound;
    #AlreadyOwned;
    #NotEnoughCoin;
    #NotAdmin;
  };
};
