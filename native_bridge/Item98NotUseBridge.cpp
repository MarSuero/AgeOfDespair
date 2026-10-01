#include <reframework/API.hpp>

#include <atomic>
#include <cstdint>
#include <string>

using namespace reframework;

namespace {

thread_local bool g_skipped_target = false;
std::atomic_bool g_logged_target{false};

int on_not_use_item_pre(
    int argc,
    void** argv,
    REFrameworkTypeDefinitionHandle*,
    unsigned long long
) {
    g_skipped_target = false;
    if (argc < 3 || argv == nullptr) {
        return REFRAMEWORK_HOOK_CALL_ORIGINAL;
    }

    // HookManager supplies: [0] VM context, [1] this, [2] first method arg.
    const auto item_id = static_cast<int32_t>(
        reinterpret_cast<uintptr_t>(argv[2])
    );
    if (item_id != 98) {
        return REFRAMEWORK_HOOK_CALL_ORIGINAL;
    }

    g_skipped_target = true;
    if (!g_logged_target.exchange(true)) {
        API::get()->log_info(
            "[mhws-eatshit] notUseItem gate bypass armed for public item 98"
        );
    }
    return REFRAMEWORK_HOOK_SKIP_ORIGINAL;
}

void on_not_use_item_post(
    void** ret_val,
    REFrameworkTypeDefinitionHandle,
    unsigned long long
) {
    if (!g_skipped_target) {
        return;
    }

    // notUseItem returns System.Boolean. False means the item is not blocked.
    if (ret_val != nullptr) {
        *ret_val = nullptr;
    }
    g_skipped_target = false;
    API::get()->log_info(
        "[mhws-eatshit] notUseItem returned false for public item 98"
    );
}

API::Method* find_not_use_item_method(API::TypeDefinition* type) {
    if (type == nullptr) {
        return nullptr;
    }

    for (auto* method : type->get_methods()) {
        if (std::string(method->get_name()) != "notUseItem") {
            continue;
        }
        if (method->is_static() || method->get_num_params() != 1) {
            continue;
        }

        const auto params = method->get_params();
        auto* param_type = reinterpret_cast<API::TypeDefinition*>(params[0].t);
        auto* return_type = method->get_return_type();
        if (param_type == nullptr || return_type == nullptr) {
            continue;
        }
        if (param_type->get_full_name() != "app.ItemDef.ID") {
            continue;
        }
        if (return_type->get_full_name() != "System.Boolean") {
            continue;
        }
        return method;
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
    auto* type = api->tdb()->find_type("app.mcHunterItem");
    auto* method = find_not_use_item_method(type);
    if (method == nullptr) {
        api->log_error(
            "[mhws-eatshit] notUseItem(app.ItemDef.ID) was not found"
        );
        return false;
    }

    const auto hook_id = method->add_hook(
        on_not_use_item_pre,
        on_not_use_item_post,
        false
    );
    api->log_info(
        "[mhws-eatshit] notUseItem gate bridge installed id=%u address=%p",
        hook_id,
        method->get_function_raw()
    );
    return true;
}
