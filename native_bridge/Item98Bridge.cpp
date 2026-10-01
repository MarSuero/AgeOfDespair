#include <reframework/API.hpp>

#include <Windows.h>

#include <atomic>
#include <string>

using namespace reframework;

namespace {

std::atomic_bool g_dumped{false};

void log_type(API::TypeDefinition* type) {
    if (type == nullptr) {
        return;
    }

    auto* api = API::get();
    api->log_info("[mhws-eatshit] native metadata type=%s", type->get_full_name().c_str());

    for (auto* field : type->get_fields()) {
        api->log_info(
            "[mhws-eatshit] native metadata field=%s offset=%u static=%d",
            field->get_name(),
            field->get_offset_from_base(),
            field->is_static() ? 1 : 0
        );
    }

    for (auto* method : type->get_methods()) {
        std::string signature = method->get_name();
        signature += "(";
        const auto params = method->get_params();
        for (size_t i = 0; i < params.size(); ++i) {
            if (i != 0) {
                signature += ", ";
            }
            auto* param_type = static_cast<API::TypeDefinition*>(params[i].t);
            signature += param_type != nullptr ? param_type->get_full_name() : "<unknown>";
        }
        signature += ")";

        auto* return_type = method->get_return_type();
        api->log_info(
            "[mhws-eatshit] native metadata method=%s return=%s static=%d address=%p",
            signature.c_str(),
            return_type != nullptr ? return_type->get_full_name().c_str() : "<unknown>",
            method->is_static() ? 1 : 0,
            method->get_function_raw()
        );
    }
}

void on_present() {
    if (g_dumped.exchange(true)) {
        return;
    }

    auto* api = API::get();
    auto* tdb = api->tdb();

    log_type(tdb->find_type("app.mcHunterItem"));
    log_type(tdb->find_type("app.HunterCharacter"));
    api->log_info("[mhws-eatshit] native metadata dump complete; no hooks installed");
}

} // namespace

extern "C" __declspec(dllexport)
void reframework_plugin_required_version(REFrameworkPluginVersion* version) {
    version->major = REFRAMEWORK_PLUGIN_VERSION_MAJOR;
    version->minor = REFRAMEWORK_PLUGIN_VERSION_MINOR;
    version->patch = REFRAMEWORK_PLUGIN_VERSION_PATCH;
    version->game_name = "mhwilds";
}

extern "C" __declspec(dllexport)
bool reframework_plugin_initialize(const REFrameworkPluginInitializeParam* param) {
    API::initialize(param);
    param->functions->on_present(on_present);
    param->functions->log_info("[mhws-eatshit] native metadata bridge initialized");
    return true;
}
