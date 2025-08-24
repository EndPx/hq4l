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
import Order "mo:base/Order";
import Types "./types";
import Int "mo:base/Int";

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
  // Immutable view untuk User
  public type UserView = {
    id : Types.UserId;
    owner_principal : Principal;
    username : Text;
    coin : Nat;
    stamina : Nat;
    last_action_timestamp : Time.Time;
    skins : [InventoryItemView]; // ganti ke view yang immutable
    quests : [QuestView]; // ganti ke view juga
  };

  public type CurrentRoleView = {
    id : Types.CurrentRoleId;
    role_name : Text;
    level : Nat;
    exp : Nat;
    is_active : Bool;
  };

  // Gabungan profile
  type UserProfileView = {
    user : UserView;
    roles : [CurrentRoleView];
    active_inventory : ?Types.InventoryItem;
  };

  type ActiveInventoryView = {
    id : Types.InventoryId;
    skin_id : Types.SkinId;
    user_id : Types.UserId;
    is_active : Bool;
    acquired_at : Time.Time;
    skin_name : Text;
    skin_description : Text;
    skin_image_url : Text;
  };

  type ShopView = {
    available : [Types.Skin];
    owned : [Types.Skin];
  };

  public type QuestView = {
    id : Nat;
    user_id : Types.UserId;
    title : Text;
    description : Text;
    stamina_cost : Nat;
    coin_reward : Nat;
    exp_reward : Nat;
    deadline : Time.Time;
    status : Types.QuestStatus;
    accepted_at : Time.Time;
  };


  public type InventoryItemView = {
    id : Types.InventoryId;
    skin_id : Types.SkinId;
    user_id : Types.UserId;
    is_active : Bool;
    acquired_at : Time.Time;
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
      quests = Array.map<Types.Quest, QuestView>(u.quests, toQuestView);
    };
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
    };
  };

  private func toQuestView(q : Types.Quest) : QuestView {
    {
      id = q.id;
      user_id = q.user_id;
      title = q.title;
      description = q.description;
      stamina_cost = q.stamina_cost;
      coin_reward = q.coin_reward;
      exp_reward = q.exp_reward;
      deadline = q.deadline;
      status = q.status;
      accepted_at = q.accepted_at;
    };
  };


  // ======================================
  // STATE: User & Roles
  // ======================================
  private var users_stable : [(Principal, Types.User)] = [];
  private transient var users = HashMap.HashMap<Principal, Types.User>(0, Principal.equal, Principal.hash);

  private var current_roles_stable : [(Types.CurrentRoleId, Types.CurrentRole)] = [];
  private transient var current_roles = HashMap.HashMap<Types.CurrentRoleId, Types.CurrentRole>(0, Nat.equal, Hash.hash);

  private var next_user_id : Types.UserId = 0;
  private var next_current_role_id : Types.CurrentRoleId = 0;
  private var next_quest_id : Nat = 0;

  // ======================================
  // STATE: Shop & Inventory
  // ======================================
  private var skins_stable : [(Types.SkinId, Types.Skin)] = [];
  private transient var skins = HashMap.HashMap<Types.SkinId, Types.Skin>(0, Nat.equal, Hash.hash);

  private var inventories_stable : [(Principal, [Types.InventoryItem])] = [];
  private transient var inventories = HashMap.HashMap<Principal, [Types.InventoryItem]>(0, Principal.equal, Principal.hash);

  private var next_skin_id : Types.SkinId = 0;
  private var next_inventory_id : Types.InventoryId = 0;

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
  // STAMINA
  // ======================================

  let INITIAL_STAMINA : Nat = 30;
  let REGEN_INTERVAL : Nat = 5 * 60 * 1_000_000_000;
  let REGEN_AMOUNT : Nat = 1;

  private func regenerateStamina(u : Types.User) {
    let now = Time.now();
    let elapsedInt = now - u.last_action_timestamp;
    if (elapsedInt <= 0) return;

    let elapsed : Nat = Int.abs(elapsedInt);

    if (elapsed >= REGEN_INTERVAL) {
      let periods = elapsed / REGEN_INTERVAL;
      let regen = periods * REGEN_AMOUNT;

      if (u.stamina < INITIAL_STAMINA) {
        u.stamina := Nat.min(INITIAL_STAMINA, u.stamina + regen);
      };

      // update timestamp supaya akurat
      let remainder = elapsed % REGEN_INTERVAL;
      u.last_action_timestamp := now - remainder;
    };
  };

  public shared (msg) func getStamina() : async Result.Result<Nat, Types.UserError> {
    switch (users.get(msg.caller)) {
      case null {
        return #err(#UserNotFound);
      };
      case (?u) {
        // regen dulu biar selalu up-to-date
        regenerateStamina(u);
        return #ok(u.stamina);
      };
    };
  };

  // ======================================
  // USER REGISTER
  // ======================================

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
    image_url : Text,
    price : Nat,
  ) : async Result.Result<Types.SkinId, Types.ShopError> {
    if (msg.caller != ADMIN) {
      return #err(#NotAdmin);
    };

    let newSkin : Types.Skin = {
      id = next_skin_id;
      name = name;
      description = description;
      image_url = image_url;
      price = price;
    };

    skins.put(next_skin_id, newSkin);
    next_skin_id += 1;
    #ok(newSkin.id);
  };

  // ======================================
  // ADMIN: Grant Coin
  // ======================================
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
  // QUEST
  // ======================================

  public shared (msg) func acceptQuest(
    title : Text,
    description : Text,
    stamina_cost : Nat,
    coin_reward : Nat,
    exp_reward : Nat
  ) : async Result.Result<(), Types.UserError> {
    let ?u = users.get(msg.caller) else return #err(#UserNotFound);

    // ✅ Cek role dulu
    switch (current_roles.get(u.id)) {
      case null {
        return #err(#NoActiveRole);   // UserError baru misalnya
      };
      case (?role) {
        // ✅ Cek stamina
        if (u.stamina < stamina_cost) {
          return #err(#NotEnoughStamina);
        };

        u.stamina -= stamina_cost;

        let now = Time.now();
        let four_hours : Int = 4 * 60 * 60 * 1_000_000_000;
        let deadline = now + four_hours;

        let newQuest : Types.Quest = {
          id = next_quest_id;
          user_id = u.id;
          title = title;
          description = description;
          stamina_cost = stamina_cost;
          coin_reward = coin_reward;
          exp_reward = exp_reward;
          deadline = deadline;
          var status = #OnProgress;
          accepted_at = now;
        };

        next_quest_id += 1;
        u.quests := Array.append(u.quests, [newQuest]);

        #ok(());
      };
    };
  };



  public shared query (msg) func detailQuest(questId : Nat) : async ?QuestView {
    let ?u = users.get(msg.caller) else return null;

    switch (Array.find<Types.Quest>(u.quests, func(q) { q.id == questId })) {
      case null {
        null;
      };
      case (?q) {
        if (q.user_id == u.id) {
          ?toQuestView(q);
        } else {
          null;
        };
      };
    };
  };

  public shared query (msg) func historyQuest() : async {
    onProgress : [QuestView];
    completed : [QuestView];
    failed : [QuestView];
  } {
    let ?u = users.get(msg.caller) else return {
      onProgress = [];
      completed = [];
      failed = [];
    };

    let onProgress = Array.map<Types.Quest, QuestView>(
      Array.filter<Types.Quest>(
        u.quests,
        func(q) { q.status == #OnProgress and q.user_id == u.id },
      ),
      toQuestView,
    );

    let completed = Array.map<Types.Quest, QuestView>(
      Array.filter<Types.Quest>(
        u.quests,
        func(q) { q.status == #Completed and q.user_id == u.id },
      ),
      toQuestView,
    );

    let failed = Array.map<Types.Quest, QuestView>(
      Array.filter<Types.Quest>(
        u.quests,
        func(q) { q.status == #Failed and q.user_id == u.id },
      ),
      toQuestView,
    );

    { onProgress; completed; failed };
  };

  // Tandai semua quest expired jadi Failed
  public shared (msg) func failExpiredQuests() : async () {
    let ?u = users.get(msg.caller) else return ();

    let now = Time.now();

    for (q in u.quests.vals()) {
      if (q.user_id == u.id and q.status == #OnProgress and now > q.deadline) {
        q.status := #Failed; // ✅ hanya quest caller yang diganti
      };
    };
  };

  // Selesaikan quest tertentu
  public shared (msg) func completeQuest(questId : Nat) : async Result.Result<(), Text> {
    let ?u = users.get(msg.caller) else return #err("User not found");

    switch (Array.find<Types.Quest>(u.quests, func(q) { q.id == questId })) {
      case null {
        return #err("Quest not found");
      };
      case (?quest) {
        // ✅ pastikan quest ini milik caller
        if (quest.user_id != u.id) {
          return #err("Forbidden: quest does not belong to you");
        };
        if (quest.status != #OnProgress) {
          return #err("Quest is not in progress");
        };

        // Tandai selesai
        quest.status := #Completed;

        // === 🎁 Beri reward ===
        u.coin += quest.coin_reward;

        // Cari role aktif user
        // Asumsi ada 1 role aktif per user (atau bisa multi-role kalau kamu pakai current_roles)
        switch (current_roles.get(u.id)) {
          case null { /* user belum punya role, lewati exp */ };
          case (?role) {
            // Tambah exp (misalnya exp = stamina_cost * 10)
            role.exp += quest.exp_reward;

            // Cek level up
            let newLevel = calcLevel(role.exp);
            if (newLevel > role.level) {
              role.level := newLevel; // Naik level
            };
          };
        };

        #ok(());
      };
    };
  };

  // ======================================
  // SHOP & INVENTORY
  // ======================================
  public shared query (msg) func getShop() : async ShopView {
    // Ambil semua skin
    let allSkins = Iter.toArray(skins.vals());

    // Ambil inventory user
    let inv = switch (inventories.get(msg.caller)) {
      case null { [] };
      case (?items) { items };
    };

    // Ambil daftar skin_id yang dimiliki user
    let ownedSkinIds = Array.map<Types.InventoryItem, Types.SkinId>(inv, func(item) { item.skin_id });

    // Available = skin yang id-nya TIDAK ada di ownedSkinIds
    let available = Array.filter<Types.Skin>(
      allSkins,
      func(s) {
        switch (Array.find<Nat>(ownedSkinIds, func(id) { id == s.id })) {
          case null { true }; // tidak ditemukan → available
          case (?_) { false }; // ditemukan → berarti owned
        };
      },
    );

    // Owned = skin yang id-nya ADA di ownedSkinIds
    let owned = Array.filter<Types.Skin>(
      allSkins,
      func(s) {
        switch (Array.find<Nat>(ownedSkinIds, func(id) { id == s.id })) {
          case null { false };
          case (?_) { true };
        };
      },
    );

    {
      available = available;
      owned = owned;
    };
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
              user_id = u.id;
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

  public shared (msg) func setActiveInventory(inventory_id : Types.InventoryId) : async Result.Result<(), Text> {
    let caller = msg.caller;

    // Ambil semua inventory milik user
    let inv = switch (inventories.get(caller)) {
      case null { return #err("User has no inventory") };
      case (?items) { items };
    };

    // Cek apakah inventory_id valid & milik user
    var found = false;
    var newInv = Array.map<Types.InventoryItem, Types.InventoryItem>(
      inv,
      func(item) {
        if (item.id == inventory_id) {
          found := true;
          if (item.is_active) {
            // toggle ke false
            { item with is_active = false };
          } else {
            // aktifkan item ini
            { item with is_active = true };
          };
        } else {
          // non-aktifkan semua lainnya
          { item with is_active = false };
        };
      },
    );

    if (not found) {
      return #err("Inventory item not found or not owned by caller");
    };

    inventories.put(caller, newInv);
    #ok(());
  };

  // ======================================
  // PROFILE
  // ======================================

  private func calcLevel(exp : Nat) : Nat {
    if (exp >= 5000) { return 5 };
    if (exp >= 1500) { return 4 };
    if (exp >= 500) { return 3 };
    if (exp >= 200) { return 2 };
    return 1; // default (awal)
  };

  public shared query (msg) func getProfileUser() : async ?UserProfileView {
    switch (users.get(msg.caller)) {
      case null { null };
      case (?u) {
        regenerateStamina(u);

        let roles = Array.filter<Types.CurrentRole>(
          Iter.toArray(current_roles.vals()),
          func(r) { r.user_id == u.id },
        );
        let roleViews = Array.map<Types.CurrentRole, CurrentRoleView>(roles, toCurrentRoleView);

        let inv = switch (inventories.get(msg.caller)) {
          case null { [] };
          case (?items) { items };
        };
        let activeInvOpt = Array.find<Types.InventoryItem>(inv, func(item) { item.is_active });
        let activeViewOpt = switch (activeInvOpt) {
          case null { null };
          case (?item) {
            switch (skins.get(item.skin_id)) {
              case null { null };
              case (?skin) {
                ?{
                  id = item.id;
                  skin_id = item.skin_id;
                  user_id = u.id;
                  is_active = item.is_active;
                  acquired_at = item.acquired_at;
                  skin_name = skin.name;
                  skin_description = skin.description;
                  skin_image_url = skin.image_url;
                };
              };
            };
          };
        };

        // 🔹 Filter hanya quest onProgress
        let activeQuests : [QuestView] = Array.map<Types.Quest, QuestView>(
          Array.filter<Types.Quest>(u.quests, func(q) { q.status == #OnProgress }),
          toQuestView,
        );

        ?{
          user = {
            id = u.id;
            owner_principal = u.owner_principal;
            username = u.username;
            coin = u.coin;
            stamina = u.stamina;
            last_action_timestamp = u.last_action_timestamp;
            skins = u.skins;
            quests = activeQuests;
          };
          roles = roleViews;
          active_inventory = activeViewOpt;
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

  public shared (msg) func chooseRole(role_to_select : Types.RoleSelection) : async Result.Result<(), Types.UserError> {
    let caller = msg.caller;
    let ?user = users.get(caller) else return #err(#UserNotFound);

    // ✅ Cek quest aktif, kalau ada → tolak
    let hasActiveQuest = switch (
      Array.find<Types.Quest>(
        user.quests,
        func(q) { q.status == #OnProgress },
      )
    ) {
      case null false;
      case (?_) true;
    };
    if (hasActiveQuest) {
      return #err(#ActiveQuestExists);
    };

    let role_id_to_select = roleSelectionToId(role_to_select);

    var found = false;
    for ((id, r) in current_roles.entries()) {
      if (r.user_id == user.id) {
        if (r.role_id == role_id_to_select) {
          r.is_active := true;   // ✅ Role yang dipilih jadi aktif
          found := true;
        } else {
          r.is_active := false;  // ✅ Role lain dipaksa nonaktif
        };
        current_roles.put(id, r);
      };
    };

    if (not found) { return #err(#RoleNotFound) };

    #ok(());
  };



  // ======================================
  // LEADERBOARD
  // ======================================
  public shared query (msg) func getLeaderboardAllUserByRole(
    role_id : Types.RoleId
  ) : async [Types.LeaderboardEntry] {
    // 1. Ambil semua role dan filter berdasarkan role_id
    let all_roles = Iter.toArray(current_roles.vals());
    let filtered_roles = Array.filter<Types.CurrentRole>(
      all_roles,
      func(r) { r.role_id == role_id },
    );

    // 2. Urutkan role berdasarkan EXP secara descending
    func compare(a : Types.CurrentRole, b : Types.CurrentRole) : Order.Order {
      if (a.exp > b.exp) { return #less }; // a dulu
      if (b.exp > a.exp) { return #greater }; // b dulu
      return #equal;
    };
    let sorted_roles = Array.sort<Types.CurrentRole>(filtered_roles, compare);

    // 3. Buat map user_id → user
    let user_id_map = HashMap.HashMap<Types.UserId, Types.User>(
      users.size(),
      Nat.equal,
      Hash.hash,
    );
    for ((_, u) in users.entries()) {
      user_id_map.put(u.id, u);
    };

    // 4. Buffer hasil leaderboard
    let result_buf = Buffer.Buffer<Types.LeaderboardEntry>(sorted_roles.size() + 1);

    // 4a. Tambahkan caller di index [0]
    switch (users.get(msg.caller)) {
      case null {
        // caller belum terdaftar → tidak ditambahkan
      };
      case (?callerUser) {
        // cari role caller untuk role_id ini
        let callerRoleOpt = Array.find<Types.CurrentRole>(
          filtered_roles,
          func(r) { r.user_id == callerUser.id },
        );
        switch (callerRoleOpt) {
          case null {
            // user belum punya role ini
            result_buf.add({
              user_id = callerUser.id;
              username = callerUser.username;
              level = 0;
              exp = 0;
            });
          };
          case (?callerRole) {
            result_buf.add({
              user_id = callerUser.id;
              username = callerUser.username;
              level = callerRole.level;
              exp = callerRole.exp;
            });
          };
        };
      };
    };

    // 4b. Tambahkan semua entry leaderboard
    var i : Nat = 0;
    while (i < sorted_roles.size()) {
      let role = sorted_roles[i];
      switch (user_id_map.get(role.user_id)) {
        case null {};
        case (?user) {
          result_buf.add({
            user_id = user.id;
            username = user.username;
            level = role.level;
            exp = role.exp;
          });
        };
      };
      i += 1;
    };

    // 5. Return array
    return Buffer.toArray(result_buf);
  };

};
