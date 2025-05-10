#!/bin/bash

# 设置颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}开始全面清除SubConverter特征标头...${NC}"

# 检测操作系统类型，以便使用正确的sed参数
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS系统
    SED_CMD="sed -i ''"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    # Windows环境(Git Bash, Cygwin, WSL等)
    SED_CMD="sed -i"
else
    # 默认Linux
    SED_CMD="sed -i"
fi

# 创建临时目录
TEMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'subconverter-temp')
trap 'rm -rf "$TEMP_DIR"' EXIT

# 备份关键文件
# echo -e "${YELLOW}备份关键文件...${NC}"
# cp src/handler/webget.cpp src/handler/webget.cpp.bak
# cp src/server/webserver_libevent.cpp src/server/webserver_libevent.cpp.bak
# cp src/server/webserver_httplib.cpp src/server/webserver_httplib.cpp.bak
# cp src/server/webserver.h src/server/webserver.h.bak

# 处理webget.cpp文件中的标头和User-Agent
echo -e "${YELLOW}修改 src/handler/webget.cpp...${NC}"
# 1. 删除SubConverter-Request和SubConverter-Version标头
$SED_CMD '/header_list = curl_slist_append(header_list, "SubConverter-Request: 1");/d' src/handler/webget.cpp
$SED_CMD '/header_list = curl_slist_append(header_list, "SubConverter-Version: " VERSION);/d' src/handler/webget.cpp

# 2. 删除SubConverter的X-Requested-With标头
# sed -i 's/X-Requested-With: subconverter " VERSION/X-Requested-With: curl/' src/handler/webget.cpp

# 3. 修改User-Agent，避免暴露SubConverter身份
# sed -i 's/static auto user_agent_str = "subconverter\/" VERSION " cURL\/" LIBCURL_VERSION;/static auto user_agent_str = "Mozilla\/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit\/537.36 (KHTML, like Gecko) Chrome\/120.0.0.0 Safari\/537.36";/' src/handler/webget.cpp

# 处理webserver.h中的User-Agent
# echo -e "${YELLOW}修改 src/server/webserver.h...${NC}"
# sed -i 's/std::string user_agent_str = "subconverter\/" VERSION " cURL\/" LIBCURL_VERSION;/std::string user_agent_str = "Mozilla\/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit\/537.36 (KHTML, like Gecko) Chrome\/120.0.0.0 Safari\/537.36";/' src/server/webserver.h

# 处理webserver_libevent.cpp文件中的标头检测
echo -e "${YELLOW}修改 src/server/webserver_libevent.cpp...${NC}"

# 替换定义行，保留uri变量
$SED_CMD 's/const char \*uri = req->uri, \*internal_flag = evhttp_find_header(req->input_headers, "SubConverter-Request");/const char *uri = req->uri;/' src/server/webserver_libevent.cpp

# 找到并删除if (internal_flag != nullptr)及其完整代码块
# 使用awk更可靠地处理括号匹配问题
awk '
BEGIN {print_line=1; skip_block=0; brackets=0;}
{
    if ($0 ~ /if \(internal_flag != nullptr\)/) {
        skip_block=1;
        brackets=0;
    }
    
    if (skip_block) {
        if ($0 ~ /\{/) brackets++;
        if ($0 ~ /\}/) brackets--;
        
        if (brackets == 0 && $0 ~ /\}/) {
            skip_block=0;
            next;
        }
        
        if (skip_block) next;
    }
    
    if (print_line) print $0;
}' src/server/webserver_libevent.cpp > "$TEMP_DIR/webserver_libevent.cpp"
cat "$TEMP_DIR/webserver_libevent.cpp" > src/server/webserver_libevent.cpp

# 处理webserver_httplib.cpp文件中的标头检测和Server响应头
echo -e "${YELLOW}修改 src/server/webserver_httplib.cpp...${NC}"

# 找到并删除if (req.has_header("SubConverter-Request"))及其完整代码块
# 使用awk更可靠地处理括号匹配问题
awk '
BEGIN {print_line=1; skip_block=0; brackets=0;}
{
    if ($0 ~ /if \(req\.has_header\("SubConverter-Request"\)\)/) {
        skip_block=1;
        brackets=0;
    }
    
    if (skip_block) {
        if ($0 ~ /\{/) brackets++;
        if ($0 ~ /\}/) brackets--;
        
        if (brackets == 0 && $0 ~ /\}/) {
            skip_block=0;
            next;
        }
        
        if (skip_block) next;
    }
    
    if (print_line) print $0;
}' src/server/webserver_httplib.cpp > "$TEMP_DIR/webserver_httplib.cpp"
cat "$TEMP_DIR/webserver_httplib.cpp" > src/server/webserver_httplib.cpp

# 修改Server响应头，不再暴露SubConverter信息
# sed -i 's/res\.set_header("Server", "subconverter\/" VERSION " cURL\/" LIBCURL_VERSION);/res.set_header("Server", "nginx");/' src/server/webserver_httplib.cpp

echo -e "${GREEN}特征标头清除完成！${NC}"
# echo -e "${YELLOW}注意: 如果编译出现问题，可以使用备份文件恢复原始状态。${NC}" 