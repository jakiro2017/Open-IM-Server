reload=open_im_api
pkill -f $reload
#open_im_cms_api  
#open_im_demo  
#open_im_msg_gateway  
#open_im_msg_transfer  
#open_im_push
#rpc
#FMT=' cd /src/cmd/%s && make build && dlv exec ./%s --headless --log --log-output dap,debugger --listen=:2345 --api-version=2'
FMT=' cd /src/cmd/%s && go mod tidy && go build -gcflags="all=-N -l" -o %s main.go && dlv exec /src/cmd/%s/%s --headless --log --log-output dap,debugger --listen=:2345 --api-version=2'
command=$(printf "$FMT" $reload $reload $reload $reload)
#print $test
#reflex -r '/src/.go$' -s -- sh -c $test
cd /src && reflex -r  '\.go$' -s -- sh -c $command