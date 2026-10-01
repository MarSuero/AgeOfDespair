#include <reframework/API.hpp>

#include <atomic>
#include <cstdint>
#include <string>

using namespace reframework;

namespace {

thread_local bool g_item98_selected = false;
thread_local API::ManagedObject* g_last_action = nullptr;
thread_local bool g_last_action_is_drink = false;
thread_local bool g_last_action_activated = false;
std::atomic_bool g_logged_activation{false};

void activate_stench() {
    auto& api = API::get();
    auto* manager = api->get_managed_singleton("app.PlayerManager");
    auto* master = manager != nullptr
        ? manager->call<API::ManagedObject*>("getMasterPlayer")
        : nullptr;
    auto* character = master != nullptr
        ? master->call<API::ManagedObject*>("get_Character")
        : nullptr;
    if (character == nullptr) {
        return;
    }

    auto* hunter_status =
        character->call<API::ManagedObject*>("get_HunterStatus");
    auto* bad_conditions = hunter_status != nullptr
        ? hunter_status->call<API::ManagedObject*>("get_BadConditions")
        : nullptr;
    auto* stench_field = bad_conditions != nullptr
        ? bad_conditions->get_field<API::ManagedObject*>("_Stench")
        : nullptr;
    auto* stench = stench_field != nullptr ? *stench_field : nullptr;

    if (stench == nullptr) {
        api->log_error(
            "[mhws-eatshit] action-end stench bridge: receiver lookup failed"
        );
        return;
    }

    stench->call<void>("requestActivate");
    if (!g_logged_activation.exchange(true)) {
        api->log_info(
            "[mhws-eatshit] stench activated at cUseDrinkItem action end"
        );
    }
}

int on_not_use_item_pre(
    int argc,
    void** argv,
    REFrameworkTypeDefinitionHandle*,
    unsigned long long
) {
    if (argc >= 3 && argv != nullptr) {
        const auto item_id = static_cast<int32_t>(
            reinterpret_cast<uintptr_t>(argv[2])
        );
        g_item98_selected = item_id == 98;
    }
    return REFRAMEWORK_HOOK_CALL_ORIGINAL;
}

int on_action_end_pre(
    int argc,
    void** argv,
    REFrameworkTypeDefinitionHandle*,
    unsigned long long
) {
    g_last_action = nullptr;
    g_last_action_is_drink = false;
    g_last_action_activated = false;

    if (argc < 2 || argv == nullptr || !g_item98_selected) {
        return REFRAMEWORK_HOOK_CALL_ORIGINAL;
    }

    auto* action = reinterpret_cast<API::ManagedObject*>(argv[1]);
    if (action == nullptr) {
        return REFRAMEWORK_HOOK_CALL_ORIGINAL;
    }

    auto* type = action->get_type_definition();
    if (type == nullptr) {
        return REFRAMEWORK_HOOK_CALL_ORIGINAL;
    }

    g_last_action = action;
    g_last_action_is_drink =
        type->get_full_name() == "app.PlayerCommonSubAction.cUseDrinkItem";
    return REFRAMEWORK_HOOK_CALL_ORIGINAL;
}

void on_action_end_post(
    void** ret_val,
    REFrameworkTypeDefinitionHandle,
    unsigned long long
) {
    if (!g_item98_selected
        || !g_last_action_is_drink
        || g_last_action == nullptr
        || g_last_action_activated
        || ret_val == nullptr) {
        return;
    }

    const auto ended = reinterpret_cast<uintptr_t>(*ret_val) != 0;
    if (!ended) {
        return;
    }

    g_last_action_activated = true;
    activate_stench();
}

API::Method* find_method(
    API::TypeDefinition* type,
    const char* name,
    const char* return_name,
    uint32_t param_count
) {
    if (type == nullptr) {
        return nullptr;
    }
    for (auto* method : type->get_methods()) {
        if (std::string(method->get_name()) != name
            || method->get_num_params() != param_count) {
            continue;
        }
        auto* ret = method->get_return_type();
        if (ret != nullptr && ret->get_full_name() == return_name) {
            return method;
        }
    }
    return nullptr;
}

} // namespace

extern "C" __declspec(dllexport)
void reframework_plugin_required_version(REFrameworkPluginVersion* version) {
    version->major = REFRAMEWORK_PLUGIN_VERSION_MAJOR;
    version->minor = REFRAMEWORK_PLUGIN_VERSION_MINOR;
    version->patch = REFRAMEWORK_PLUGIN_VERSION_PATCH;
    version->game_name = nullptr;
}

extern "C" __declspec(dllexport)
bool reframework_plugin_initialize(const REFrameworkPluginInitializeParam* param) {
    auto& api = API::initialize(param);
    auto* item_type = api->tdb()->find_type("app.mcHunterItem");
    auto* action_type = api->tdb()->find_type("app.cHunterSubActionBase");
    auto* item_method = find_method(item_type, "notUseItem", "System.Boolean", 1);
    auto* action_method = find_method(action_type, "isSubActionEnd", "System.Boolean", 0);

    if (item_method == nullptr || action_method == nullptr) {
        api->log_error(
            "[mhws-eatshit] action-end stench bridge: required methods missing"
        );
        return false;
    }

    item_method->add_hook(on_not_use_item_pre, nullptr, false);
    action_method->add_hook(on_action_end_pre, on_action_end_post, false);
    api->log_info(
        "[mhws-eatshit] action-end stench bridge installed"
    );
    return true;
}
