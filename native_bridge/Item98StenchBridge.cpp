#include <reframework/API.hpp>

#include <atomic>
#include <cstdint>
#include <string>

using namespace reframework;

namespace {

thread_local bool g_target_use = false;
thread_local API::ManagedObject* g_character = nullptr;
std::atomic_bool g_logged_activation{false};

int on_used_item_pre(
    int argc,
    void** argv,
    REFrameworkTypeDefinitionHandle*,
    unsigned long long
) {
    g_target_use = false;
    g_character = nullptr;

    // Instance method layout: [0] VM context, [1] this, [2] item ID.
    if (argc < 3 || argv == nullptr) {
        return REFRAMEWORK_HOOK_CALL_ORIGINAL;
    }

    const auto item_id = static_cast<int32_t>(
        reinterpret_cast<uintptr_t>(argv[2])
    );
    if (item_id != 98) {
        return REFRAMEWORK_HOOK_CALL_ORIGINAL;
    }

    g_target_use = true;
    g_character = reinterpret_cast<API::ManagedObject*>(argv[1]);
    return REFRAMEWORK_HOOK_CALL_ORIGINAL;
}

void activate_stench() {
    if (g_character == nullptr) {
        return;
    }

    auto* hunter_status =
        g_character->call<API::ManagedObject*>("get_HunterStatus");
    if (hunter_status == nullptr) {
        API::get()->log_error(
            "[mhws-eatshit] stench bridge: get_HunterStatus returned nil"
        );
        return;
    }

    auto* bad_conditions =
        hunter_status->call<API::ManagedObject*>("get_BadConditions");
    if (bad_conditions == nullptr) {
        API::get()->log_error(
            "[mhws-eatshit] stench bridge: get_BadConditions returned nil"
        );
        return;
    }

    auto* stench_field =
        bad_conditions->get_field<API::ManagedObject*>("_Stench");
    auto* stench = stench_field != nullptr ? *stench_field : nullptr;
    if (stench == nullptr) {
        API::get()->log_error(
            "[mhws-eatshit] stench bridge: _Stench returned nil"
        );
        return;
    }

    stench->call<void>("requestActivate");
    if (!g_logged_activation.exchange(true)) {
        API::get()->log_info(
            "[mhws-eatshit] stench activated after public item 98 use"
        );
    }
}

void on_used_item_post(
    void**,
    REFrameworkTypeDefinitionHandle,
    unsigned long long
) {
    if (!g_target_use) {
        return;
    }

    activate_stench();
    g_target_use = false;
    g_character = nullptr;
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
    auto* type = api->tdb()->find_type("app.HunterCharacter");
    if (type == nullptr) {
        api->log_error("[mhws-eatshit] stench bridge: HunterCharacter missing");
        return false;
    }

    API::Method* method = nullptr;
    for (auto* candidate : type->get_methods()) {
        if (std::string(candidate->get_name()) != "set_UsedItemID") {
            continue;
        }
        if (candidate->get_num_params() != 1) {
            continue;
        }
        const auto params = candidate->get_params();
        auto* param_type = reinterpret_cast<API::TypeDefinition*>(params[0].t);
        if (param_type != nullptr
            && param_type->get_full_name() == "app.ItemDef.ID") {
            method = candidate;
            break;
        }
    }

    if (method == nullptr) {
        api->log_error(
            "[mhws-eatshit] stench bridge: set_UsedItemID(app.ItemDef.ID) missing"
        );
        return false;
    }

    const auto hook_id = method->add_hook(
        on_used_item_pre,
        on_used_item_post,
        false
    );
    api->log_info(
        "[mhws-eatshit] item98 stench bridge installed id=%u address=%p",
        hook_id,
        method->get_function_raw()
    );
    return true;
}
