use futures::channel::oneshot;
use log::info;
use std::marker::PhantomData;
use std::net::SocketAddr;
use tokio::runtime;

#[derive(Debug, Clone, Copy)]
pub(crate) enum Protocol {
    Http,
    #[allow(unused)]
    Https,
}

pub(crate) struct ServerId<'pool> {
    shutdown: Option<oneshot::Sender<()>>,
    pub url: SocketAddr,
    _phant: PhantomData<&'pool ServerPool>,
}

/// Drop will block until all `ServerId`'s are dropped (so do not mem forget
/// them).
pub(crate) struct ServerPool {
    rt: runtime::Runtime,
}

impl ServerPool {
    pub fn new() -> anyhow::Result<Self> {
        Ok(Self {
            rt: runtime::Runtime::new()?,
        })
    }

    pub fn start<F>(
        &self,
        filter: F,
        p: Protocol,
        a: impl Into<SocketAddr> + Send + 'static,
    ) -> ServerId<'_>
    where
        F: warp::Filter + Clone + Send + Sync + 'static,
        F::Extract: warp::Reply,
    {
        let (tx, rx) = oneshot::channel();
        let (url_tx, url_rx) = crossbeam::channel::bounded(1);
        self.rt.spawn(async move {
            match p {
                Protocol::Http => {
                    let (url, server) = warp::serve(filter).bind_with_graceful_shutdown(a, async {
                        rx.await.ok();
                    });
                    url_tx.send(url).unwrap();
                    server.await;
                }
                Protocol::Https => {
                    let (url, server) = warp::serve(filter)
                        .tls()
                        .cert(include_bytes!("../../embed-assets/cert.pem"))
                        .key(include_bytes!("../../embed-assets/key.key"))
                        .bind_with_graceful_shutdown(a, async {
                            rx.await.ok();
                        });
                    url_tx.send(url).unwrap();
                    server.await;
                }
            };
        });
        let url = url_rx.recv().unwrap();
        info!("Starting {:?} server at {}", p, url);
        ServerId {
            url,
            shutdown: Some(tx),
            _phant: PhantomData,
        }
    }
}

impl<'pool> Drop for ServerId<'pool> {
    fn drop(&mut self) {
        self.shutdown.take().unwrap().send(()).unwrap();
    }
}
