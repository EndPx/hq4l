import Time "mo:base/Time";

module {
  public type RoleId = Nat;
  public type CurrentRoleId = Nat;
  public type SkinId = Nat;
  public type InventoryId = Nat;
  public type QuestId = Nat;
  public type UserId = Nat;

  // =============================
  // ROLES
  // =============================
  public type Role = {
    id : RoleId;
    name : Text;
    badge : Text;
  };

  public type RoleSelection = {
    #Codes;
    #Sports;
    #Arts;
    #Traveler;
    #Literature;
  };

  public type CurrentRole = {
    id : CurrentRoleId;
    role_id : RoleId;
    user_id : UserId;
    var level : Nat;
    var exp : Nat;
    var is_active : Bool;
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
  // USER (gabungan User + UserProfile)
  // =============================
  public type User = {
    id : UserId;
    owner_principal : Principal;
    username : Text;
    var coin : Nat;
    var stamina : Nat;
    var last_action_timestamp : Time.Time;
    var skins : [InventoryItem];
    var quests : [Quest];
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
