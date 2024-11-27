# src/models/model.py

import pytorch_lightning as pl
import torch
from torch import nn
import timm

from torchmetrics import Accuracy, F1Score, AUROC, MeanMetric
from src.utils.metrics import get_metrics


class ImageClassifier(pl.LightningModule):
    def __init__(self, model_name: str, pretrained: bool, num_classes: int, learning_rate: float,
                 weight_decay: float, scheduler: str, scheduler_step_size: int, scheduler_gamma: float,
                 optimizer: str = "Adam"):
        super().__init__()
        self.save_hyperparameters()

        self.model = timm.create_model(model_name, pretrained=pretrained, num_classes=num_classes)
        self.criterion = nn.CrossEntropyLoss()

        self._train_loss = MeanMetric()
        self._valid_loss = MeanMetric()
        metrics = get_metrics(
            num_classes=num_classes,
            task='multiclass',
            average='macro',
        )

        self.train_metrics = metrics.clone(prefix='train_')
        self.val_metrics = metrics.clone(prefix='val_')

    def forward(self, x):
        return self.model(x)

    def training_step(self, batch, batch_idx):
        images, labels = batch
        logits = self.forward(images)
        loss = self.criterion(logits, labels)

        preds = torch.argmax(logits, dim=1)

        self._train_loss.update(loss)
        for metric in self.train_metrics.values():
            metric.update(preds, labels)

        self.log('train_loss', self._train_loss.compute(), logger=True, on_step=True, on_epoch=True, prog_bar=True)
        self.log_dict({k: v.compute() for k, v in self.train_metrics.items()}, on_step=False, on_epoch=True, prog_bar=True)

        return loss

    def validation_step(self, batch, batch_idx):
        images, labels = batch
        logits = self.forward(images)
        loss = self.criterion(logits, labels)
        self._valid_loss.update(loss)

        preds = torch.argmax(logits, dim=1)

        for metric in self.val_metrics.values():
            metric.update(preds, labels)

        self.log('val_loss', self._valid_loss.compute(), on_step=False, on_epoch=True, prog_bar=True)
        self.log_dict({k: v.compute() for k, v in self.val_metrics.items()}, prog_bar=True, on_epoch=True)

        return {'loss': loss, 'preds': preds}

    def on_train_epoch_end(self):
        self._train_loss.reset()
        for metric in self.train_metrics.values():
            metric.reset()

    def on_validation_epoch_end(self):
        self._valid_loss.reset()
        for metric in self.val_metrics.values():
            metric.reset()

    def configure_optimizers(self):
        optimizer = getattr(torch.optim, self.hparams.optimizer)(
            self.parameters(),
            lr=self.hparams.learning_rate,
            weight_decay=self.hparams.weight_decay
        )

        if self.hparams.scheduler == "StepLR":
            scheduler = torch.optim.lr_scheduler.StepLR(
                optimizer,
                step_size=self.hparams.scheduler_step_size,
                gamma=self.hparams.scheduler_gamma
            )
            return {
                "optimizer": optimizer,
                "lr_scheduler": {
                    "scheduler": scheduler,
                    "monitor": "val_loss",
                },
            }
        elif self.hparams.scheduler == "CosineAnnealingLR":
            scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(
                optimizer,
                T_max=self.hparams.scheduler_step_size
            )
            return {
                "optimizer": optimizer,
                "lr_scheduler": {
                    "scheduler": scheduler,
                    "monitor": "val_loss",
                },
            }
        else:
            return optimizer
