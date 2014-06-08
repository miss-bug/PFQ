#include <iostream>
#include <string>
#include <stdexcept>
#include <chrono>

#include <pfq.hpp>
using namespace net;

int
main(int argc, char *argv[])
{
    if (argc < 2)
        throw std::runtime_error(std::string("usage: ").append(argv[0]).append(" dev"));

    pfq q(128);

    q.bind(argv[1], pfq::any_queue);

    auto gid = q.group_id();

    auto prog = reinterpret_cast<pfq_computation_descr *>(malloc(sizeof(size_t) * 2 + sizeof(pfq_functional_descr) * 5));

    prog->size = 5;
    prog->entry_point = 0;

    prog->fun[0].symbol = "ip";
    prog->fun[0].arg[0] = { nullptr, 0 };
    prog->fun[0].arg[1] = { nullptr, 0 };
    prog->fun[0].arg[2] = { nullptr, 0 };
    prog->fun[0].arg[3] = { nullptr, 0 };
    prog->fun[0].left     = 1;
    prog->fun[0].right    = 1;

    prog->fun[1].symbol = "conditional";
    prog->fun[0].arg[0] = { nullptr, 0 };
    prog->fun[0].arg[1] = { nullptr, 0 };
    prog->fun[0].arg[2] = { nullptr, 0 };
    prog->fun[0].arg[3] = { nullptr, 0 };
    prog->fun[1].left   = 3;
    prog->fun[1].right  = 4;

    prog->fun[2].symbol = "is_icmp";
    prog->fun[0].arg[0] = { nullptr, 0 };
    prog->fun[0].arg[1] = { nullptr, 0 };
    prog->fun[0].arg[2] = { nullptr, 0 };
    prog->fun[0].arg[3] = { nullptr, 0 };
    prog->fun[2].left   = -1;
    prog->fun[2].right  = -1;

    prog->fun[3].symbol = "steer_ip";
    prog->fun[0].arg[0] = { nullptr, 0 };
    prog->fun[0].arg[1] = { nullptr, 0 };
    prog->fun[0].arg[2] = { nullptr, 0 };
    prog->fun[0].arg[3] = { nullptr, 0 };
    prog->fun[3].left   = -1;
    prog->fun[3].right  = -1;

    prog->fun[4].symbol = "drop";
    prog->fun[0].arg[0] = { nullptr, 0 };
    prog->fun[0].arg[1] = { nullptr, 0 };
    prog->fun[0].arg[2] = { nullptr, 0 };
    prog->fun[0].arg[3] = { nullptr, 0 };
    prog->fun[4].left   = -1;
    prog->fun[4].right  = -1;

    q.set_group_computation(gid, prog);

    q.enable();

    for(;;)
    {
            auto many = q.read( 1000000 /* timeout: micro */);

            queue::iterator it = many.begin();
            queue::iterator it_e = many.end();

            for(; it != it_e; ++it)
            {
                    while (!it.ready()) {
                        std::this_thread::yield();
                    }

                    printf("vlan:%d caplen:%d len:%d ifindex:%d hw_queue:%d -> ",
                           it->un.vlan.vlan_vid, it->caplen, it->len, it->if_index, it->hw_queue);

                    char *buff = static_cast<char *>(it.data());

                    for(int x=0; x < std::min<int>(it->caplen, 34); x++)
                    {
                        printf("%2x ", (unsigned char)buff[x]);
                    }
                    printf("\n");
            }
    }

    return 0;
}
