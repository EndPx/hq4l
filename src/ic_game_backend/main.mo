import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Nat "mo:base/Nat";
import HashMap "mo:base/HashMap";
import Result "mo:base/Result";
import Option "mo:base/Option";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Hash "mo:base/Hash";
import Array "mo:base/Array";

import Types "./types";

persistent actor {

  // ======================================
  // AVAILABLE ROLES
  // ======================================
  private transient let available_roles = HashMap.fromIter<Types.RoleId, Types.Role>(
    Iter.fromArray([
      (0, { id = 0; name = "Codes"; badge = "badge_code.png" }),
      (1, { id = 1; name = "Sports"; badge = "badge_sports.png" }),
      (2, { id = 2; name = "Arts"; badge = "badge_arts.png" }),
      (3, { id = 3; name = "Traveler"; badge = "badge_traveler.png" }),
      (4, { id = 4; name = "Literature"; badge = "badge_literature.png" }),
    ]),
    5,
    Nat.equal,
    Hash.hash,
  );

  // ======================================
  // ADMIN CONFIG
  // ======================================
  let ADMIN : Principal = Principal.fromText(
    "dkd3q-uab23-y7epq-teeyt-u2zi2-h3oqx-amjgd-e3k5u-mk7ms-zxcz2-mae"
  );

  // ======================================
  // HELPER
  // ======================================

  // Immutable view untuk User
  type UserView = {
    id : Types.UserId;
    owner_principal : Principal;
    username : Text;
    coin : Nat;
    stamina : Nat;
    last_action_timestamp : Time.Time;
    skins : [Types.InventoryItem];
    quests : [Types.Quest];
  };

  // View untuk current role (lebih ringkas)
  type CurrentRoleView = {
    id : Types.CurrentRoleId;
    role_name : Text;   // dari available_roles
    level : Nat;
    exp : Nat;
    is_active : Bool;
  };

  // Gabungan profile
  type UserProfileView = {
    user : UserView;
    roles : [CurrentRoleView];
  };



  private func toUserView(u : Types.User) : UserView {
    {
      id = u.id;
      owner_principal = u.owner_principal;
      username = u.username;
      coin = u.coin;
      stamina = u.stamina;
      last_action_timestamp = u.last_action_timestamp;
      skins = u.skins;
      quests = u.quests;
    }
  };

  private func toCurrentRoleView(r : Types.CurrentRole) : CurrentRoleView {
    let roleName = switch (available_roles.get(r.role_id)) {
      case null { "Unknown" };
      case (?role) { role.name };
    };
    {
      id = r.id;
      role_name = roleName;
      level = r.level;
      exp = r.exp;
      is_active = r.is_active;
    }
  };


  // ======================================
  // STATE: User & Roles
  // ======================================
  private stable var users_stable : [(Principal, Types.User)] = [];
  private transient var users = HashMap.HashMap<Principal, Types.User>(0, Principal.equal, Principal.hash);

  private stable var current_roles_stable : [(Types.CurrentRoleId, Types.CurrentRole)] = [];
  private transient var current_roles = HashMap.HashMap<Types.CurrentRoleId, Types.CurrentRole>(0, Nat.equal, Hash.hash);

  private stable var next_user_id : Types.UserId = 0;
  private stable var next_current_role_id : Types.CurrentRoleId = 0;
  
  // ======================================
  // STATE: Shop & Inventory
  // ======================================
  private stable var skins_stable : [(Types.SkinId, Types.Skin)] = [];
  private transient var skins = HashMap.HashMap<Types.SkinId, Types.Skin>(0, Nat.equal, Hash.hash);

  private stable var inventories_stable : [(Principal, [Types.InventoryItem])] = [];
  private transient var inventories = HashMap.HashMap<Principal, [Types.InventoryItem]>(0, Principal.equal, Principal.hash);

  private stable var next_skin_id : Types.SkinId = 0;
  private stable var next_inventory_id : Types.InventoryId = 0;

  // ======================================
  // SYSTEM HOOKS
  // ======================================
  system func preupgrade() {
    users_stable := Iter.toArray(users.entries());
    current_roles_stable := Iter.toArray(current_roles.entries());
    skins_stable := Iter.toArray(skins.entries());
    inventories_stable := Iter.toArray(inventories.entries());
  };

  system func postupgrade() {
    for ((p, u) in users_stable.vals()) { users.put(p, u) };
    for ((id, cr) in current_roles_stable.vals()) { current_roles.put(id, cr) };
    for ((id, s) in skins_stable.vals()) { skins.put(id, s) };
    for ((p, inv) in inventories_stable.vals()) { inventories.put(p, inv) };

    users_stable := [];
    current_roles_stable := [];
    skins_stable := [];
    inventories_stable := [];
  };

  // ======================================
  // USER REGISTER
  // ======================================
  let INITIAL_STAMINA : Nat = 30;

  public shared (msg) func registerUser(username : Text) : async Result.Result<(UserView, [CurrentRoleView]), Types.RegistrationError> {
    let caller_principal = msg.caller;

    if (not Option.isNull(users.get(caller_principal))) {
      return #err(#AlreadyRegistered);
    };

    for ((_, user) in users.entries()) {
      if (user.username == username) {
        return #err(#UsernameTaken);
      };
    };

    let newUser : Types.User = {
      id = next_user_id;
      owner_principal = caller_principal;
      username = username;
      var coin = 0;
      var stamina = INITIAL_STAMINA;
      var last_action_timestamp = Time.now();
      var skins = [];
      var quests = [];
    };
    next_user_id += 1;
    users.put(caller_principal, newUser);

    var rolesBuf = Buffer.Buffer<Types.CurrentRole>(available_roles.size());
    for ((rid, _) in available_roles.entries()) {
      let cr : Types.CurrentRole = {
        id = next_current_role_id;
        role_id = rid;
        user_id = newUser.id;
        var level = 1;
        var exp = 0;
        var is_active = false;
      };
      current_roles.put(next_current_role_id, cr);
      rolesBuf.add(cr);
      next_current_role_id += 1;
    };

    let rolesArr = Buffer.toArray(rolesBuf);
    #ok((toUserView(newUser), Array.map<Types.CurrentRole, CurrentRoleView>(rolesArr, toCurrentRoleView)));
  };


  // ======================================
  // ADMIN: Tambah Skin
  // ======================================
  public shared (msg) func addSkin(
    name : Text,
    description : Text,
    rarity : Text,
    image_url : Text,
    is_limited : Bool,
    price : Nat,
  ) : async Result.Result<Types.SkinId, Types.ShopError> {
    if (msg.caller != ADMIN) {
      return #err(#NotAdmin);
    };

    let newSkin : Types.Skin = {
      id = next_skin_id;
      name = name;
      description = description;
      rarity = rarity;
      image_url = image_url;
      is_limited = is_limited;
      price = price;
    };

    skins.put(next_skin_id, newSkin);
    next_skin_id += 1;
    #ok(newSkin.id);
  };

  // ======================================
  // ADMIN: Grant Coin
  // ======================================
  public shared (msg) func grantCoin(target : Principal, amount : Nat) : async Result.Result<(), Text> {
    if (msg.caller != ADMIN) {
      return #err("Unauthorized: Only admin can grant coin");
    };

    switch (users.get(target)) {
      case null { return #err("User not found") };
      case (?u) {
        u.coin += amount;
        users.put(target, u);
        #ok(());
      };
    };
  };

  public shared (msg) func grantCoinByUsername(username : Text, amount : Nat) : async Result.Result<(), Text> {
    if (msg.caller != ADMIN) {
      return #err("Unauthorized: Only admin can grant coin");
    };

    label userSearch for ((p, u) in users.entries()) {
      if (u.username == username) {
        u.coin += amount;
        users.put(p, u);
        return #ok(());
      };
    };

    #err("User not found");
  };

  // ======================================
  // SHOP & INVENTORY
  // ======================================
  public shared query func getShop() : async [Types.Skin] {
    Iter.toArray(skins.vals());
  };

  public shared (msg) func buySkin(skin_id : Types.SkinId) : async Result.Result<(), Types.ShopError> {
    let caller = msg.caller;

    switch (users.get(caller)) {
      case null { return #err(#UserNotFound) };
      case (?u) {
        switch (skins.get(skin_id)) {
          case null { return #err(#SkinNotFound) };
          case (?skin) {
            let inv = switch (inventories.get(caller)) {
              case null { [] };
              case (?items) { items };
            };

            for (item in inv.vals()) {
              if (item.skin_id == skin_id) {
                return #err(#AlreadyOwned);
              };
            };

            if (u.coin < skin.price) {
              return #err(#NotEnoughCoin);
            };

            u.coin -= skin.price;

            let newItem : Types.InventoryItem = {
              id = next_inventory_id;
              skin_id = skin.id;
              is_active = false;
              acquired_at = Time.now();
            };
            next_inventory_id += 1;

            inventories.put(caller, Array.append(inv, [newItem]));
            #ok(());
          };
        };
      };
    };
  };

  public shared query (msg) func getInventory() : async [Types.InventoryItem] {
    switch (inventories.get(msg.caller)) {
      case null { [] };
      case (?items) { items };
    };
  };

  // ======================================
  // PROFILE
  // ======================================
  private func getProfileUserInternal(caller : Principal) : ?Types.User {
    users.get(caller);
  };

  public shared query (msg) func getProfileUser() : async ?UserProfileView {
    switch (users.get(msg.caller)) {
      case null { null };
      case (?u) {
        let roles = Array.filter<Types.CurrentRole>(
          Iter.toArray(current_roles.vals()),
          func(r) { r.user_id == u.id }
        );

        let roleViews = Array.map<Types.CurrentRole, CurrentRoleView>(roles, toCurrentRoleView);

        ?{
          user = toUserView(u);
          roles = roleViews;
        };
      };
    };
  };



  // ======================================
  // USER HELPERS
  // ======================================
  public shared query (msg) func isUserExists() : async Bool {
    not Option.isNull(users.get(msg.caller));
  };

  private func roleSelectionToId(selection : Types.RoleSelection) : Types.RoleId {
    switch (selection) {
      case (#Codes) { 0 };
      case (#Sports) { 1 };
      case (#Arts) { 2 };
      case (#Traveler) { 3 };
      case (#Literature) { 4 };
    };
  };

  public shared (msg) func chooseRole(role_to_toggle : Types.RoleSelection) : async Result.Result<(), Types.UserError> {
    let caller = msg.caller;
    let ?user = users.get(caller) else return #err(#UserNotFound);

    let role_id_to_toggle = roleSelectionToId(role_to_toggle);

    var found = false;
    for ((id, r) in current_roles.entries()) {
      if (r.user_id == user.id and r.role_id == role_id_to_toggle) {
        r.is_active := not r.is_active;
        current_roles.put(id, r);
        found := true;
      };
    };

    if (not found) { return #err(#RoleNotFound) };

    #ok(());
  };
};
