#pragma once

#include <mutex>
#include <string>

namespace CyrodiilMP::GameClient {

class Log
{
public:
    static void Initialize(std::string path);
    static void Write(std::string message);

private:
    static std::mutex mutex;
    static std::string path;
};

}
