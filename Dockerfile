# sudo docker tag bfb683ce23df chat_llm_torch:v1
# chat_llm_torch:v2
FROM chat_llm_torch:v1
RUN rm -rf /usr/lib/x86_64-linux-gnu/libnvidia-*
RUN rm -rf /usr/lib/x86_64-linux-gnu/libcuda.so*
# sudo docker build -t chat_llm_torch:v2 .