FROM node:10

ENV POLLING_INTERVAL=5000
ENV LOG_LEVEL=debug
ENV RPC=https://rpc.fusenet.io
ENV CONSENSUS_ADDRESS=0x3014ca10b91cb3D0AD85fEf7A3Cb95BCAc9c0f79

COPY ./ ./
RUN npm install --only=prod

CMD ["node", "index.js"]