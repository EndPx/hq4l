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
  // STATE: User, Roles
  // ======================================
  private stable var users_stable : [(Principal, Types.User)] = [];
  private transient var users = HashMap.HashMap<Principal, Types.User>(0, Principal.equal, Principal.hash);

  private stable var user_roles_stable : [(Principal, [Types.CurrentRole])] = [];
  private transient var user_roles = HashMap.HashMap<Principal, [Types.CurrentRole]>(0, Principal.equal, Principal.hash);

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
    user_roles_stable := Iter.toArray(user_roles.entries());
    skins_stable := Iter.toArray(skins.entries());
    inventories_stable := Iter.toArray(inventories.entries());
  };

  system func postupgrade() {
    for ((p, u) in users_stable.vals()) { users.put(p, u) };
    for ((p, rs) in user_roles_stable.vals()) { user_roles.put(p, rs) };
    for ((id, s) in skins_stable.vals()) { skins.put(id, s) };
    for ((p, inv) in inventories_stable.vals()) { inventories.put(p, inv) };

    users_stable := [];
    user_roles_stable := [];
    skins_stable := [];
    inventories_stable := [];
  };

  // ======================================
  // USER REGISTER
  // ======================================
  let INITIAL_STAMINA : Nat = 100;

  public shared (msg) func registerUser(username : Text) : async Result.Result<Types.UserProfile, Types.RegistrationError> {
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
      owner_principal = caller_principal;
      username = username;
      var coin = 0;
      var stamina = INITIAL_STAMINA;
      var last_action_timestamp = Time.now();
    };
    users.put(caller_principal, newUser);

    let buffer = Buffer.Buffer<Types.CurrentRole>(available_roles.size());
    for ((rid, _) in available_roles.entries()) {
      let cr : Types.CurrentRole = {
        id = next_current_role_id;
        role_id = rid;
        var level = 1;
        var exp = 0;
        var is_active = false;
      };
      next_current_role_id += 1;
      buffer.add(cr);
    };
    user_roles.put(caller_principal, Buffer.toArray(buffer));

    #ok(getProfileUserInternal(caller_principal));
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

    // cari principal berdasarkan username
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

  public shared (msg) func activateSkin(inventory_id : Types.InventoryId) : async Result.Result<(), Types.ShopError> {
    let caller = msg.caller;
    switch (inventories.get(caller)) {
      case null { return #err(#UserNotFound) };
      case (?items) {
        var targetItem : ?Types.InventoryItem = null;
        // 1. Temukan item yang dituju untuk mengetahui statusnya saat ini
        for (item in items.vals()) {
          if (item.id == inventory_id) {
            targetItem := ?item;
          };
        };

        switch (targetItem) {
          case null { return #err(#SkinNotFound) };
          case (?t) {
            // 2. Tentukan status aktif berikutnya (kebalikan dari status saat ini)
            let shouldBeActive = not t.is_active;

            let updated = Buffer.Buffer<Types.InventoryItem>(items.size());

            for (item in items.vals()) {
              if (item.id == inventory_id) {
                // Untuk item yang dipilih, atur statusnya menjadi `shouldBeActive`
                updated.add({ item with is_active = shouldBeActive });
              } else {
                // Untuk item lain:
                if (shouldBeActive) {
                  // Jika item target sedang diaktifkan, maka semua item lain harus dinonaktifkan.
                  updated.add({ item with is_active = false });
                } else {
                  // Jika item target sedang dinonaktifkan, status item lain tidak berubah (karena sudah non-aktif).
                  updated.add(item);
                };
              };
            };
            inventories.put(caller, Buffer.toArray(updated));
            #ok(());
          };
        };
      };
    };
  };

  // ======================================
  // PROFILE
  // ======================================
  private func getProfileUserInternal(caller : Principal) : Types.UserProfile {
    let ?user = users.get(caller) else {
      return {
        username = "";
        coin = 0;
        stamina = 0;
        roles = [];
        skins = [];
        quests = [];
      };
    };

    var role_profiles : [Types.RoleProfile] = [];
    switch (user_roles.get(caller)) {
      case (?roles) {
        let buf = Buffer.Buffer<Types.RoleProfile>(roles.size());
        for (cr in roles.vals()) {
          switch (available_roles.get(cr.role_id)) {
            case (?mr) {
              buf.add({
                id = cr.id;
                name = mr.name;
                badge = mr.badge;
                level = cr.level;
                exp = cr.exp;
                is_active = cr.is_active;
              });
            };
            case null {};
          };
        };
        role_profiles := Buffer.toArray(buf);
      };
      case null {};
    };

    // MODIFIKASI: Filter inventaris untuk hanya mendapatkan skin yang aktif.
    let active_skins = Array.filter<Types.InventoryItem>(
      switch (inventories.get(caller)) {
        case null { [] };
        case (?inv) { inv };
      },
      func(item) { item.is_active },
    );

    {
      username = user.username;
      coin = user.coin;
      stamina = user.stamina;
      roles = role_profiles;
      skins = active_skins; // Gunakan hasil filter
      quests = []; // placeholder
    };
  };

  public shared query (msg) func getProfileUser() : async ?Types.UserProfile {
    if (Option.isNull(users.get(msg.caller))) {
      return null;
    };
    ?getProfileUserInternal(msg.caller);
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

    // 1. Konversi input dropdown (variant) menjadi angka (RoleId)
    let role_id_to_toggle = roleSelectionToId(role_to_toggle);

    if (Option.isNull(users.get(caller))) { return #err(#UserNotFound) };

    switch (user_roles.get(caller)) {
      case null { return #err(#RoleNotFound) };
      case (?roles) {
        let buf = Buffer.Buffer<Types.CurrentRole>(roles.size());
        var roleFound = false;

        // 2. Sisa logika fungsi sama persis seperti sebelumnya
        for (r in roles.vals()) {
          if (r.role_id == role_id_to_toggle) {
            roleFound := true;
            buf.add({
              id = r.id;
              role_id = r.role_id;
              var level = r.level;
              var exp = r.exp;
              var is_active = not r.is_active;
            });
          } else {
            buf.add(r);
          };
        };

        if (not roleFound) {
          // Error ini secara teknis tidak akan pernah tercapai karena pilihan dropdown pasti valid,
          // tapi tetap baik untuk ada.
          return #err(#RoleNotFound);
        };

        user_roles.put(caller, Buffer.toArray(buf));
        #ok(());
      };
    };
  };

  // ======================================
  // DEBUG
  // ======================================
  public shared query func debugUsers() : async [(Principal, Types.DebugUser)] {
    Iter.toArray(
      Iter.map<(Principal, Types.User), (Principal, Types.DebugUser)>(
        users.entries(),
        func((p, u)) {
          (p, { owner_principal = u.owner_principal; username = u.username; coin = u.coin; stamina = u.stamina; last_action_timestamp = u.last_action_timestamp });
        },
      )
    );
  };

  public shared query func debugSkins() : async [(Types.SkinId, Types.Skin)] {
    Iter.toArray(skins.entries());
  };

  public shared query func debugInventories() : async [(Principal, [Types.InventoryItem])] {
    Iter.toArray(inventories.entries());
  };

  public shared query (msg) func whoami() : async Text {
    Principal.toText(msg.caller);
  };
};
