#include <reframework/API.hpp>

#include <cstdint>
#include <string>

using namespace reframework;

namespace {

thread_local bool g_target_call = false;
thread_local bool g_static_method = false;

API::Method* find_action_type_method(API::TypeDefinition* type) {
    if (type == nullptr) {
        return nullptr;
    }

    for (auto* method : type->get_methods()) {
        if (std::string(method->get_name()) != "getItemActionTypeFromItemID") {
            continue;
        }
        if (method->get_num_params() != 1) {
            continue;
        }

        const auto params = method->get_params();
        auto* param_type = reinterpret_cast<API::TypeDefinition*>(params[0].t);
        if (param_type == nullptr
            || param_type->get_full_name() != "app.ItemDef.ID") {
            continue;
        }
        return method;
    }
    return nullptr;
}

int on_action_type_pre(
    int argc,
    void** argv,
    REFrameworkTypeDefinitionHandle*,
    unsigned long long
) {
    g_target_call = false;
    const auto item_arg_index = g_static_method ? 1 : 2;
    if (argc <= item_arg_index || argv == nullptr) {
        return REFRAMEWORK_HOOK_CALL_ORIGINAL;
    }

    const auto item_id = static_cast<int32_t>(
        reinterpret_cast<uintptr_t>(argv[item_arg_index])
    );
    if (item_id == 98) {
        g_target_call = true;
    }
    return REFRAMEWORK_HOOK_CALL_ORIGINAL;
}

void on_action_type_post(
    void** ret_val,
    REFrameworkTypeDefinitionHandle,
    unsigned long long
) {
    if (!g_target_call) {
        return;
    }

    // Verified BTable mapping: action type 2 is cEatMeat.
    if (ret_val != nullptr) {
        *ret_val = reinterpret_cast<void*>(static_cast<uintptr_t>(2));
    }
    g_target_call = false;
    API::get()->log_info(
        "[mhws-eatshit] item 98 action type overridden to 2 (cEatMeat)"
    );
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
    auto* type = api->tdb()->find_type("app.HunterItemActionTable");
    auto* method = find_action_type_method(type);
    if (method == nullptr) {
        api->log_error(
            "[mhws-eatshit] getItemActionTypeFromItemID(app.ItemDef.ID) not found"
        );
        return false;
    }

    g_static_method = method->is_static();
    const auto hook_id = method->add_hook(
        on_action_type_pre,
        on_action_type_post,
        false
    );
    api->log_info(
        "[mhws-eatshit] cEatMeat action bridge installed id=%u static=%d address=%p",
        hook_id,
        g_static_method ? 1 : 0,
        method->get_function_raw()
    );
    return true;
}
